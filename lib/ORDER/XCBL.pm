package ORDER::XCBL;

use strict;

use lib "/backend/lib";
use XML::Writer;
use POSIX qw (strftime);

sub epoch2xmltime {
	my ($t) = @_;
	return ( strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)));
	}


##
## outputs an ORDER as xCBL version 4.0 format http://www.xcbl.org
##
sub as_xcbl {
	my ($O2) = @_;
	my $xCBL = '';

	my $writer = new XML::Writer(OUTPUT => \$xCBL, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
	my $order_id = $O2->oid();
	# supplier_order_id is usually the same as the source order id.
	# but it COULD be something different, it's not order_id.
	if ($O2->is_supplier_order()) {
		$order_id = $O2->supplier_orderid();
		}

	# if (($order_id eq '*') && (defined $self->{'supplier_order_id'})) { $order_id = $self->{'supplier_order_id'}; }

	$writer->startTag("Order",
							"xmlns:core" => "rrn:org.xcbl:schemas/xcbl/v4_0/core/core.xsd",
							"xmlns" => "rrn:org.xcbl:schemas/xcbl/v4_0/ordermanagement/v1_0/ordermanagement.xsd",
							"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
							"xsi:schemaLocation" => "rrn:org.xcbl:schemas/xcbl/v4_0/ordermanagement/v1_0/ordermanagement.xsd ../../schema/org/xcbl/path_delim/schemas/xcbl/v4_0/ordermanagement/v1_0/ordermanagement.xsd"
	); #need for minimal xcbl, don't remove ('min' from here)

	# --OrderHeader START--
	$writer->startTag("OrderHeader"); #min
	$writer->startTag("OrderNumber"); #min
		$writer->dataElement("BuyerOrderNumber", $order_id); #min, <ORDER ID=...> in our xml, no?
	$writer->endTag("OrderNumber"); #min

	my $data_created = &ZTOOLKIT::unixtime_to_gmtime($O2->in_get('our/order_ts')); #convert into xsd:dateTime
	$data_created =~ s/\s/T/; #convert into xsd:dateTime (need for validity)
	$writer->dataElement("OrderIssueDate", $data_created); #min, xsd:dateTime (iso 8601), like '2001-10-26T21:32:52', <created> in our xml

	$writer->startTag("OrderCurrency"); #min
		$writer->dataElement("core:CurrencyCoded", "USD"); #min, no such in our xml, set to 'USD'
	$writer->endTag("OrderCurrency"); #min

	$writer->startTag("OrderLanguage"); #min
		$writer->dataElement("core:LanguageCoded", "en"); #min, no such in our xml, set to 'en'
	$writer->endTag("OrderLanguage"); #min

	my $data_ship_date = &ZTOOLKIT::unixtime_to_gmtime($O2->in_get('flow/shipped_ts')); #convert into xsd:dateTime
	$data_ship_date =~ s/\s/T/; #convert into xsd:dateTime (need for validity)
	$writer->startTag("OrderDates");
		$writer->dataElement("RequestedShipByDate", $data_ship_date); # <ship_date> (1184174526), converted to xsd:dateTime
	$writer->endTag("OrderDates");

	$writer->startTag("OrderParty"); #min
		$writer->startTag("BuyerParty"); #min
			$writer->startTag("core:PartyID"); #min
			$writer->dataElement("core:Ident", "Unused"); #min for OrderParty
			$writer->endTag("core:PartyID"); #min
		$writer->endTag("BuyerParty"); #min

		$writer->startTag("SellerParty"); #min
			$writer->startTag("core:PartyID"); #min
			$writer->dataElement("core:Ident", "Unused"); #min for SellerParty
			$writer->endTag("core:PartyID"); #min
		$writer->endTag("SellerParty"); #min

		$writer->startTag("ShipToParty");
			$writer->startTag("core:PartyID");
			$writer->dataElement("core:Ident", "Unused"); #min for ShipToParty
			$writer->endTag("core:PartyID");
			$writer->startTag("core:NameAddress");
			$writer->dataElement("core:Name1", $O2->in_get('ship/company')); # <ship_company>
			$writer->dataElement("core:StreetSupplement1", $O2->in_get('ship/address1')); # <ship_address1>
			$writer->dataElement("core:StreetSupplement2", $O2->in_get('ship/address2')); # <ship_address2>
			$writer->dataElement("core:PostalCode", $O2->in_get('ship/postal')); # <ship_zip>
			$writer->dataElement("core:City", $O2->in_get('ship/city')); # <ship_city>
			$writer->startTag("core:Region");
				$O2->in_get('ship/region') = '' if !$O2->in_get('ship/region'); #need for concatenation - can't be undef
				$writer->dataElement("core:RegionCoded", "US".$O2->in_get('ship/region')); # US.<ship_state>
				$writer->dataElement("core:RegionCodedOther", $O2->in_get('ship/province')); # <ship_province>
			$writer->endTag("core:Region");
			$writer->startTag("core:Country");
				$writer->dataElement("core:CountryCoded", $O2->in_get('ship/countrycode')); # <ship_countrycode>, 2 Letter code
			$writer->endTag("core:Country");
			$writer->endTag("core:NameAddress");
			$writer->startTag("core:PrimaryContact");

			$O2->in_set('ship/firstname','') if !$O2->in_get('ship/firstname'); #need for concatenation - can't be undef
			$O2->in_set('ship/middlename','') if !$O2->in_get('ship/middlename'); #need for concatenation - can't be undef
			$O2->in_set('ship/lastname','') if !$O2->in_get('ship/lastname'); #need for concatenation - can't be undef

			$writer->dataElement("core:ContactName", $O2->in_get('ship/firstname') . " " . $O2->in_get('ship/middlename') . " " . $O2->in_get('ship/lastname')); # <ship_firstname> <ship_middlename> <ship_lastname>
			$writer->startTag("core:ListOfContactNumber");
				$writer->startTag("core:ContactNumber");
					$writer->dataElement("core:ContactNumberValue", $O2->in_get('ship/phone')); # <ship_phone>
					$writer->dataElement("core:ContactNumberTypeCoded", "TelephoneNumber"); # <ship_phone>
				$writer->endTag("core:ContactNumber");
				$writer->startTag("core:ContactNumber");
					$writer->dataElement("core:ContactNumberValue", $O2->in_get('ship/email')); # <ship_email>
					$writer->dataElement("core:ContactNumberTypeCoded", "EmailAddress"); # <ship_email>
				$writer->endTag("core:ContactNumber");
			$writer->endTag("core:ListOfContactNumber");
			$writer->endTag("core:PrimaryContact");
		$writer->endTag("ShipToParty");

		$writer->startTag("BillToParty");
			$writer->startTag("core:PartyID");
			$writer->dataElement("core:Ident", "Unused"); #min for BillToParty
			$writer->endTag("core:PartyID");
			$writer->startTag("core:NameAddress");
			$writer->dataElement("core:Name1", $O2->in_get('bill/company')); # <bill_company>
			$writer->dataElement("core:StreetSupplement1", $O2->in_get('bill/address1')); # <bill_address1>
			$writer->dataElement("core:StreetSupplement2", $O2->in_get('bill/address2')); # <bill_address2>
			$writer->dataElement("core:PostalCode", $O2->in_get('bill/postal')); # <bill_zip>
			$writer->dataElement("core:City", $O2->in_get('bill/city')); # <bill_city>
			$writer->startTag("core:Region");
				$O2->in_get('bill/region') = '' if (!$O2->in_get('bill/region')); #need for concatenation - can't be undef'
				$writer->dataElement("core:RegionCoded", "US" . $O2->in_get('bill/region')); # US.<bill_state>
				$writer->dataElement("core:RegionCodedOther", $O2->in_get('bill/province')); # <bill_province>
			$writer->endTag("core:Region");
			$writer->startTag("core:Country");
				$writer->dataElement("core:CountryCoded", $O2->in_get('bill/countrycode')); # <bill_countrycode>, 2 Letter code
			$writer->endTag("core:Country");
			$writer->endTag("core:NameAddress");
			$writer->startTag("core:PrimaryContact");

			$O2->in_set('bill/firstname','') if !$O2->in_get('bill/firstname'); #need for concatenation - can't be undef
			$O2->in_set('bill/middlename','') if !$O2->in_get('bill/middlename'); #need for concatenation - can't be undef
			$O2->in_set('bill/lastname','') if !$O2->in_get('bill/lastname'); #need for concatenation - can't be undef

			$writer->dataElement("core:ContactName", $O2->in_get('bill/firstname') . " " . $O2->in_get('bill/middlename') . " " . $O2->in_get('bill/lastname')); # <bill_firstname> <bill_middlename> <bill_lastname>
			$writer->startTag("core:ListOfContactNumber");
				$writer->startTag("core:ContactNumber");
					$writer->dataElement("core:ContactNumberValue", $O2->in_get('bill/phone')); # <bill_phone>
					$writer->dataElement("core:ContactNumberTypeCoded", "TelephoneNumber"); # <bill_phone>
				$writer->endTag("core:ContactNumber");
				$writer->startTag("core:ContactNumber");
					$writer->dataElement("core:ContactNumberValue", $O2->in_get('bill/email')); # <bill_email>
					$writer->dataElement("core:ContactNumberTypeCoded", "EmailAddress"); # <bill_email>
				$writer->endTag("core:ContactNumber");
			$writer->endTag("core:ListOfContactNumber");
			$writer->endTag("core:PrimaryContact");
		$writer->endTag("BillToParty");

	$writer->endTag("OrderParty"); #min
	$writer->endTag("OrderHeader"); #min
	# --OrderHeader END--

	# --OrderDetail will be generated in STUFF.pm
	$writer->startTag("OrderDetail");
	$writer->startTag("ListOfItemDetail");

	foreach my $item (@{$O2->stuff2()->items()}) {
		my $stid = $item->{'stid'};
		$writer->startTag("ItemDetail");
			$writer->startTag("BaseItemDetail");
				$writer->startTag("LineItemNum");
					$writer->dataElement("core:BuyerLineItemNum", $stid); #min for BaseItemDelail, <product stid="3563191*GKW14672" ... in our xml
				$writer->endTag("LineItemNum");
				$writer->startTag("ItemIdentifiers");
					$writer->dataElement("core:ItemDescription", $item->{'prod_name'}); # <product prod_name= ... >
				$writer->endTag("ItemIdentifiers");
				$writer->startTag("TotalQuantity");
					$writer->dataElement("core:QuantityValue", $item->{'qty'}); # min for BaseItemDetail, <product ... qty="1" in our xml
					$writer->startTag("core:UnitOfMeasurement");
						$writer->dataElement("core:UOMCoded", "Other"); # min for TotalQuantity
					$writer->endTag("core:UnitOfMeasurement");
				$writer->endTag("TotalQuantity");
			$writer->endTag("BaseItemDetail");
			$writer->startTag("PricingDetail");
				$writer->startTag("core:ListOfPrice");
					$writer->startTag("core:Price");
						$writer->startTag("core:UnitPrice");
							$writer->dataElement("core:UnitPriceValue", $item->{'price'}); # <product price="2.75" ...>
							$writer->startTag("core:Currency");
								$writer->dataElement("core:CurrencyCoded", "USD");
							$writer->endTag("core:Currency");
						$writer->endTag("core:UnitPrice");
					$writer->endTag("core:Price");
				$writer->endTag("core:ListOfPrice");
			$writer->endTag("PricingDetail");

			$item->{'description'} = '' if !$item->{'description'}; # need for concatenate, cannot be undef
			$item->{'notes'} = '' if !$item->{'notes'}; # need for concatenate, cannot be undef
			$writer->dataElement("LineItemNote", "Description: " . $item->{'description'} . ". Notes: " . $item->{'notes'});
		$writer->endTag("ItemDetail");
		}

	$writer->endTag("ListOfItemDetail");
	$writer->endTag("OrderDetail");

	# --OrderSummary START--
	$writer->startTag("OrderSummary");

	$writer->startTag("NameValueSet");
		$writer->dataElement("SetName", "CustomShippingAttributes");
		$writer->startTag("ListOfNameValuePair");
			$writer->startTag("NameValuePair");
				$writer->dataElement("ShippingMethod", $O2->in_get('sum/shp_method'));
				$writer->dataElement("ShippingCost", $O2->in_get('sum/shp_total'));
			$writer->endTag("NameValuePair");
		$writer->endTag("ListOfNameValuePair");
	$writer->endTag("NameValueSet");

	$writer->startTag("ListOfTaxSummary");
		$writer->startTag("core:TaxSummary");
			$writer->dataElement("core:TaxTypeCoded", "Other"); # min for core:TaxSummary element
			$writer->dataElement("core:TaxFunctionQualifierCoded", "Other"); # min for core:TaxSummary element
			$writer->dataElement("core:TaxCategoryCoded", "Other"); # min for core:TaxSummary element
			$writer->dataElement("core:TaxAmount", $O2->in_get('sum/tax_total')); # <tax_total>, min for core:TaxSummary element
		$writer->endTag("core:TaxSummary");
	$writer->endTag("ListOfTaxSummary");

	$writer->startTag("OrderSubTotal");
		$writer->dataElement("core:MonetaryAmount", $O2->in_get('sum/items_total')); # <order_subtotal> in our xml
	$writer->endTag("OrderSubTotal");

	$writer->startTag("OrderTotal");
		$writer->dataElement("core:MonetaryAmount", $O2->in_get('sum/order_total')); # <order_total> in our xml
	$writer->endTag("OrderTotal");

	$writer->dataElement("SummaryNote", $O2->in_get('want/order_notes')); # <order_notes> in our xml
	$writer->endTag("OrderSummary");
	# --OrderSummary END--

	$writer->endTag("Order"); #min
	$writer->end();

#	$XML .= "<DATA>\n";
#	$XML .= &ZTOOLKIT::hashref_to_xmlish($O2->in_get((('encoder'=>'latin1');
#	$XML .= "</DATA>\n";

#	$XML .= "<STUFF>\n";
#	if ($xcompat>=108) {
#		my ($c,$error) = $self->stuff()->as_xml($xcompat);
#		$XML .= $c;
#		)
#	else {
#		## LEGACY: default compatibility level
#		my ($c,$error) = $self->stuff()->sync_serialize($self->{'username'});
#		$XML .= $c;
#		}
#	$XML .= "</STUFF>\n";

#	$XML .= "<EVENTS>\n";
#	$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'events'},'tag'=>'event','encoder'=>'latin1','content_attrib'=>'content');
#	$XML .= "</EVENTS>\n";

#	$XML .= "<GIFTCARD>\n";
#	$XML .= "</GIFTCARD>\n";

#	if (defined $self->{'fees'}) {
#		$XML .= "<FEES>\n";
#		$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->fees(1),'tag'=>'fee','encoder'=>'latin1');
#		$XML .= "</FEES>\n";
#		}

#	if (defined $self->{'tracking'}) {
#		$XML .= "<TRACKING>\n";
#		$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'tracking'},'tag'=>'pkg','encoder'=>'latin1');
#		$XML .= "</TRACKING>\n";
#		}
#	$XML .= "</ORDER>\n";

	return $xCBL;
}



1;