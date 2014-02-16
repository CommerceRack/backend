package EBAY2::ATTRIBUTES;


use strict;


###############################################################
##
## RESULT:
## csid=>
##		attributeId=>
##			'type'=>text|checkbox|calendar|
##			'@VALS'=>[val1,val2,val3]
##
sub form_to_attributereference {
	my ($formstr) = @_;

	my @FORM = [];
	if ($formstr) {
		foreach my $kv (split(/\&/,$formstr)) {
			my ($k,$v) = split(/=/,$kv,2);
			push @FORM, [ URI::Escape::XS::uri_unescape($k), URI::Escape::XS::uri_unescape($v) ];
			}
		}

	my %ATTRS = ();
	foreach my $set (@FORM) {
		my ($k,$val) = @{$set};
		if ($k =~ /attr_t([\d]+)_([\d]+)$/) { 
			## attr_tCSId_attributeId  
			## This format is generated for attributes that are to be displayed in text boxes, including other-value attributes (id="-6").
			my ($CSId,$attributeId) = ($1,$2);
			$ATTRS{$CSId}->{ $attributeId }->{'type'} = 'text';
			push @{$ATTRS{$CSId}->{ $attributeId }->{'@VALS'}}, $val;
			}
		elsif ($k =~ /attr_d([\d]+)_([\d]+)_c$/) { 
			## attr_dCSId_attributeId_c 
			## This format is generated for attributes that should be displayed as text boxes containing a full calendar date (e.g., "05/10/06") .	
			my ($CSId,$attributeId) = ($1,$2);
			$ATTRS{$CSId}->{ $attributeId }->{'type'} = 'calendar';
			push @{$ATTRS{$CSId}->{ $attributeId }->{'@VALS'}}, $val;
			}
		elsif ($k =~ /attr_d([\d]+)_([\d]+)_(.*?)$/) { 					
			## attr_dCSId_attributeId_metacharacter 
			## The ending metacharacter is either m (month), d (day), or y (year).
			## This format is generated for date drop-down lists if the format of the attribute matches the format char_char_char (e.g., "m_d_y") and the widget is a date (type="date"). For example, for a Year attribute with id = 2 in the characteristic set whose id = 10, a drop-down list is generated with the name "attr_d10_2_y".
			my ($CSId,$attributeId,$type) = ($1,$2,$3);
			$ATTRS{$CSId}->{ $attributeId }->{'type'} = $type;
			push @{$ATTRS{$CSId}->{ $attributeId }->{'@VALS'}}, $val;
			}
		elsif ($k =~ /attr_required_([\d]+)_([\d]+)$/) {
			## attr_required_CSId_attributeId=true: 
			## This format is generated to identify attributes that become required according to Type 5, Value-to-Meta-data (VM) dependencies. See Child Required-Status Dependencies (Type 5: Value-to-Meta-data).
			## my ($CSId,$attributeId) = ($1,$2);
			## nothing to see here, move along..
			}
		elsif ($k =~ /attr([\d]+)_([\d]+)$/) {
			## attrCSId_attributeId 
			## This format is generated for all other attributes.
			my ($CSId,$attributeId) = ($1,$2);
			$ATTRS{$CSId}->{ $attributeId }->{'type'} = 'value';
			push @{$ATTRS{$CSId}->{ $attributeId }->{'@VALS'}}, $val;
			}
		}
	return(\%ATTRS);
	}


##########################################################################
##
## this outputs the xml format necessary for embedding into the xsl
##
sub attributesreference_to_xslxml {
	my ($ATTRSREF) = @_;

	my $USERXML = '';
	foreach my $CSId (keys %{$ATTRSREF}) {
		$USERXML .= qq~<AttributeSet id="$CSId">\n~;
		foreach my $attributeId (keys %{$ATTRSREF->{$CSId}}) {
			$USERXML .= qq~<Attribute id="$attributeId">~;
			my $type = $ATTRSREF->{$CSId}->{$attributeId}->{'type'};
			my $VALSREF = $ATTRSREF->{$CSId}->{$attributeId}->{'@VALS'};
			if ($type eq 'text') {
				$USERXML .= "<Value>";
				foreach my $value (@{$VALSREF}) { $USERXML .= "<Name>$value</Name>\n"; }
				$USERXML .= "</Value>\n";
				}
			elsif ($type eq 'checkbox') {
				$USERXML .= "<Value><Name/></Value>\n";
				}
			else {
				foreach my $value (@{$VALSREF}) { $USERXML .= qq~<Value id=\"$value\"/>\n~; }
				}
			$USERXML .= qq~</Attribute>\n~;
			}
		$USERXML .= qq~</AttributeSet>\n~;
		}
	return($USERXML);
	}


use XML::Simple;
use XML::Parser;

sub ebayattributeset_to_attributesreference {
	my ($xml) = @_;

	my %ATTRS = ();
	my %CUSTOM = ();

	if ($xml and $xml =~ /<AttributeSetArray>/) {
		$xml =~ s/&(?!amp;|lt;|gt;)/&amp;/g; ## replace unescaped & with &amp;, but dont touch &lt;, &gt;, &amp;
		$xml =~ s/(<AttributeSetArray>.*?<\/AttributeSetArray>)(.*)/$1/s;
		my $custom_specifics = $2;
		# $xml =~ s/>[\s]+</></gs;  # this fixes purewave.

		my $ref = XML::Simple::XMLin($xml,ForceArray=>1);
		foreach my $AttributeSet (@{$ref->{'AttributeSet'}}) {
			my $attributeSetID = $AttributeSet->{'attributeSetID'};
			$ATTRS{$attributeSetID} = {};
			foreach my $Attribute (@{$AttributeSet->{'Attribute'}}) {
				my $attributeID = $Attribute->{'attributeID'};
				$ATTRS{$attributeSetID}->{$attributeID}->{'@VALS'} = [];
				foreach my $Value (@{$Attribute->{'Value'}}) {
					my $ValueID = $Value->{'ValueID'}->[0];
					push @{$ATTRS{$attributeSetID}->{$attributeID}->{'@VALS'}}, $ValueID;
					}
				}
			}

		## user defuned specs (that blue + button - add custom detail - in cs form)
		if ($custom_specifics and $custom_specifics =~ /ItemSpecifics/) {
			my $xml_parser = new XML::Parser(Style => 'Tree');
			my $ref = $xml_parser->parse($xml);
			$custom_specifics =~ s/.*?(<ItemSpecifics>.*?<\/ItemSpecifics>).*/$1/s;
			$ref = $xml_parser->parse($custom_specifics);
			$ref = $ref->[1];
			for(my $i=3; $i < scalar @$ref; $i+=4) {
				## parse NameValueLists
				$CUSTOM{$ref->[$i+1][4][2]} = $ref->[$i+1][8][2];
				}
			}
		}

	return(\%ATTRS,\%CUSTOM);
	}



#"ebay:attributeset": "
#<AttributeSetArray>
#  <AttributeSet attributeSetID=\"\">
#  </AttributeSet>
# </AttributeSetArray>
#<ItemSpecifics>
#  <NameValueList>
#    <Name>Manufacturer Part Number</Name>
#    <Value>95-FS215FLT-709BK</Value>
#  </NameValueList>
#  <NameValueList>
#    <Name>Manufacturer </Name>
#    <Value>KC International Motorcycle Supply </Value>
#  </NameValueList>
#  <NameValueList>
#    <Name>Part Brand </Name>
#    <Value>KCINT</Value>
#  </NameValueList>
#  <NameValueList>
#    <Name>Part Fitment</Name>
#    <Value>Harley Davidson</Value>
#  </NameValueList>
#</ItemSpecifics>
#"

#"ebay:attributeset": "
#<AttributeSetArray>
#  <AttributeSet attributeSetID=\"5411\">
#    <Attribute attributeID=\"10242\">
#    <Value>\t    <ValueID>-10</ValueID>
#    </Value>
#    </Attribute>
#    <Attribute attributeID=\"10244\">
#    <Value>\t    <ValueID>10425</ValueID>
#    </Value>
#    </Attribute>
#  </AttributeSet>  
#</AttributeSetArray>
#
#<ItemSpecifics>
#  <NameValueList>
#    <Name>Part Brand </Name>
#    <Value>KCINT</Value>
#  </NameValueList>
#  <NameValueList>
#    <Name>Part Fitment</Name>
#    <Value>Harley Davidson</Value>
#  </NameValueList>
#  <NameValueList>
#    <Name>OEM Replacement Number</Name>
#    <Value>Replaces OEM: #37555-41</Value>
#  </NameValueList>
#</ItemSpecifics>
#"


sub attributesreference_to_ebayattributeset {
	my ($ATTRSREF, $CUSTOMREF) = @_;

	my $USERXML = '';
	if (defined $ATTRSREF) { 
		$USERXML = "<AttributeSetArray>";	
		foreach my $CSId (keys %{$ATTRSREF}) {
			$USERXML .= qq~<AttributeSet attributeSetID="$CSId">\n~;
			foreach my $attributeId (keys %{$ATTRSREF->{$CSId}}) {
				$USERXML .= qq~<Attribute attributeID="$attributeId">~;
				my $type = $ATTRSREF->{$CSId}->{$attributeId}->{'type'};
				my $VALSREF = $ATTRSREF->{$CSId}->{$attributeId}->{'@VALS'};
				$USERXML .= "<Value>";
				foreach my $value (@{$VALSREF}) { $USERXML .= "<ValueID>$value</ValueID>\n"; }
				$USERXML .= "</Value>\n";
				$USERXML .= qq~</Attribute>\n~;
				}
			$USERXML .= qq~</AttributeSet>\n~;
			}
		$USERXML .= "</AttributeSetArray>";
		}

	if (defined $CUSTOMREF) {
		$USERXML .= "<ItemSpecifics>\n";
		foreach my $kv (keys %{$CUSTOMREF}) {
			$USERXML .= "<NameValueList><Name>$kv</Name><Value>".&ZTOOLKIT::incode($CUSTOMREF->{$kv})."</Value></NameValueList>";
			}
		$USERXML .= "</ItemSpecifics>\n";
		}	

	return($USERXML);
#  [%- IF attribute_set_id %]
#  <AttributeSetArray>
#    [%- FOREACH at_set_id = attribute_set_id %]
#    [%- IF at_set_id != 2135 %]
#    <AttributeSet attributeSetID="[% at_set_id %]">
#      [%- FOREACH attribute_id = attributes.keys %]
#      [%- IF attribute_id AND attributes.$attribute_id %]
#      <Attribute attributeID="[% attribute_id %]">
#        [%- FOREACH value = attributes.$attribute_id.value %]
#      <Value>
#       <[% attributes.$attribute_id.type %]>[% value %]</[% attributes.$attribute_id.type %]>
#      </Value>
#        [%- END %]
#      </Attribute>
#      [%- END %]
#      [%- END %]
#    </AttributeSet>
#    [%- END %]
#    [%- END %]
#    [%# return policy %]
#    [%- IF ret_policy_attributes %]
#    <AttributeSet attributeSetID="2135">
#      [%- FOREACH attribute_id = ret_policy_attributes.keys %]
#      [%- IF attribute_id AND ret_policy_attributes.$attribute_id %]
#      [%- value = ret_policy_attributes.$attribute_id.value %]
#      <Attribute attributeID="[% attribute_id %]">
#        <Value>
#        <[% ret_policy_attributes.$attribute_id.type %]>[% value %]</[% ret_policy_attributes.$attribute_id.type %]>
#       </Value>
#      </Attribute>
#      [%- END %]
#      [%- END %]
#    </AttributeSet>
#    [%- END %]
#  </AttributeSetArray>
#  [%- END %]
#
#  [%- IF custom_specifics %]
#  <ItemSpecifics>
#  [%- FOREACH cs = custom_specifics.keys %]
#    <NameValueList>
#      <Name>[% cs %]</Name>
#      [%- FOREACH cs_value = custom_specifics.$cs %]
#      <Value>[% cs_value %]</Value>
#      [%- END %]
#    </NameValueList>
#  [%- END %]
#  </ItemSpecifics>
#  [%- END %]


	}



1;