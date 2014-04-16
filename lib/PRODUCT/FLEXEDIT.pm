package PRODUCT::FLEXEDIT;


use Data::Dumper;

use strict;
require ZWEBSITE;


##
## 8/24/11 - rules for shipping amounts (ex: zoovy:ship_cost1, zoovy:ship_cost2)
##
## 1.00 is $1.00
## 0.00 is free
## -1   use marketplace rates
## -100 do not offer
##
## undef is an application defined behavior
##	marketplace specific code has the option to do expedited shipping of $0.00 is also "do not offer"
##


#
# wikihash encoding/decoding rules:
# the purpose of wikihash is to provide a simplist (wiki familiar) user input, and straightforward transport mechanism with minimal transport/framing overhead.  It is positioned as a "dwiw" (Do What I Want) approach for data input. 
#
# with wikihash:
# each line represents a new simple key, any leading or trailing whitespace on both keys or values must be stripped.
# the first colon which appears is considered the delimiter, and only the first colon shall be considered a delimiter (all other colons shall be considered part of the value)
# keys are case insensitive, and should generally be represented in lowercase.
# keys may contain the following characters: a-z 0-9 _-.
# values may contain any characters except a hard return/line feed (any key/value pair which could contain a hardreturn/linefeed is most likely not suitable for a wikihash data type and therefore outside of the scope)
# there is never any keys which are required in wikihash.
# it allows users to create/specify adhoc values in a textarea.
#
# key1 : value 1
# key2:value2
#  key3: value 3
# 
# encoded into json:
# "key1":"value 1"
# "key2":"value2"
# "key3":"value 3"
#
# wikihash does not require round trip integrity of formatting/structure. 
# For this reason it is recommended that fields be written/parsed/rested stripped in alphanumeric descending 
# order for simple comparison of tables.
#

sub wikihash_encode {
	my ($ref) = @_;
	my @lines = ();
	foreach my $k (sort %{$ref}) {
		push @lines, "$k: $ref->{$k}";
		}
	return(join("\n",@lines));	
	}

sub wikihash_decode {
	my ($str) = @_;
	
	my %ref = ();
	foreach my $line (split(/[\n\r]+/,$str)) {
		if ($line =~ /^[\s]*(.*?)[\s]*:[\s]*(.*?)$/) { $ref{lc($1)} = $ref{$2}; }
		}
	return(\%ref);
	}

#sub wikitable_encode {
#	
#	}
#
#sub wikitable_decode {
#	
#	}


# perl -e 'use lib "/backend/lib"; use Data::Dumper; use PRODUCT::FLEXEDIT; print Dumper(&PRODUCT::FLEXEDIT::elastic_fields("nyciwear"));
sub elastic_fields {
	my ($USERNAME, %options) = @_;

	##
	## NOTE: elastic_index passed in gref (where we'll eventually go to amend this hardcoded list)
	## $options{'gref'}


	## eventually this will load custom fields from webdb and append those to response.
	my @FIELDS = (
			  {
				 'index' => 'keywords',
				 'id' => 'zoovy:keywords',
				 'type' => 'textarea'
			  },
			  {
				 'index' => 'asin',
				 'id' => 'amz:asin',
				 'type' => 'asin'
			  },

			  {
				 'index' => 'related_products',
				 'id' => 'zoovy:related_products',
				 'type' => 'finder'
			  },
			  {
				 'index' => 'prod_name',
				 'id' => 'zoovy:prod_name',
				 'type' => 'text'
			  },
			  {
				 'index' => 'upc',
				 'id' => 'zoovy:prod_upc',
				 'type' => 'upc'
			  },
			  {
				 'index' => 'prod_mfgid',
				 'id' => 'zoovy:prod_mfgid',
				 'type' => 'reference'
			  },
#			  {
#				 'index' => 'prod_asm',
#				 'id' => 'zoovy:prod_asm',
#				 'type' => 'text'
#			  },
			  {
				 'index' => 'assembly',
				 'id' => 'pid:assembly',
				 'type' => 'text'
			  },
			  {
				 'index' => 'assembly',
				 'id' => 'sku:assembly',
				 'type' => 'text'
			  },
			  {
				'sku'=>1,
				 'index' => 'ean',
				 'id' => 'zoovy:prod_ean',
				 'type' => 'reference'
			  },
			  {
				 'index' => 'detail',
				 'id' => 'zoovy:prod_detail',
				 'type' => 'textarea'
			  },
			  {
				 'index' => 'salesrank',
				 'id' => 'zoovy:prod_salesrank',
				 'type' => 'textbox'
			  },
			  {
				 'index' => 'profile',
				 'id' => 'zoovy:profile',
				 'type' => 'profile'
			  },
			  {
				 'index' => 'prod_features',
				 'id' => 'zoovy:prod_features',
				 'type' => 'textarea'
			  },
			  {
				 'index' => 'base_price',
				 'id' => 'zoovy:base_price',
				 'type' => 'currency'
			  },
			  {
				 'index' => 'isbn',
				 'id' => 'zoovy:prod_isbn',
				 'type' => 'isbn'
			  },
			  {
				 'index' => 'prod_condition',
				 'id' => 'zoovy:prod_condition',
				 'type' => 'textbox'
			  },
			  {
				 'index' => 'prod_mfg',
				 'id' => 'zoovy:prod_mfg',
				 'type' => 'textbox'
			  },
			  {
				 'index' => 'accessory_products',
				 'id' => 'zoovy:accessory_products',
				 'type' => 'finder'
			  },
			  {
				 'index' => 'description',
				 'id' => 'zoovy:prod_desc',
				 'type' => 'textarea'
			  },
			  {
				 'index' => 'fakeupc',
				 'id' => 'zoovy:prod_fakeupc',
				 'type' => 'upc'
			  },
				{
				'index'=>'prod_promoclass',
				'id'=>'zoovy:prod_promoclass',
				'type'=>'textbox',
				},
				{
				'index'=>'ship_sortclass',
				'id'=>'zoovy:ship_sortclass',
				'type'=>'textbox',
				},
#				{
#				'index'=>'prod_supplierid',
#				'id'=>'zoovy:prod_supplierid',
#				'type'=>'textbox',
#				},
				{
				'index'=>'grp_parent',
				'id'=>'zoovy:grp_parent',
				'type'=>'textbox',
				},
		);

	## find additional fields for this user.
	if ($USERNAME ne '') {
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
		if (defined $gref->{'@flexedit'}) {
			foreach my $set (@{$gref->{'@flexedit'}}) {
				next unless (defined $set->{'index'});
				if (defined $PRODUCT::FLEXEDIT::fields{$set->{'id'}}) {
					## copy custom fields into global.bin ex: type, options, etc.
					foreach my $k (keys %{$PRODUCT::FLEXEDIT::fields{$set->{'id'}}}) {
						next if (defined $set->{$k});
						$set->{$k} = $PRODUCT::FLEXEDIT::fields{$set->{'id'}}->{$k};
						}
					}
				else {
					## blah, this field is totally custom.
					}
				push @FIELDS, $set;
				}
			}
		}

	my @IMAGES = (
	'zoovy:prod_banner1',
	'zoovy:prod_thumb',
	'ebay:prod_thumb',
#	'zoovy:prod_colors',
#	'zoovy:image3',
#	'zoovy:banner_01'
		);

	return(\@FIELDS,\@IMAGES);
	}



##
## 
## groups are:
##		ebay.shipping
##		ebay.profile
##
sub get_GTOOLS_Form_grp {
	my ($grp) = @_;

	my @RESULT = ();
	foreach my $k (keys %PRODUCT::FLEXEDIT::fields) {
		next unless ($PRODUCT::FLEXEDIT::fields{$k}->{'grp'} eq $grp);
		my %ref = %{$PRODUCT::FLEXEDIT::fields{$k}};		
		$ref{'key'} = $k;			# not sure where this is used anymore!?
		$ref{'id'} = $k;
#		if (ref($ref{'options'}) eq 'ARRAY') {
#			$ref{'set'} = [];
#			foreach my $opt (@{$ref{'options'}}) {
#				# push @{$ref{'set'}}, $opt->{'v'};
#				}
#			delete $ref{'options'};
#			}
		push @RESULT, \%ref;
		}
	return(\@RESULT);
	}

##
## grp=> some grouping column everything has in common.
## profile=> is a bitwise field
##			1 => allowed in profile
##			2 => normally not in product
##			4 => should never be found in product
##
##
#{ p=>"1 Day", v=>"86400" },
#{ p=>"1 Hour", v=>"3600" },
#{ p=>"10 minutes", v=>"600" },
#{ p=>"2 Hours", v=>"7200" },
#{ p=>"3 Hours", v=>"10800" },
#{ p=>"30 minutes", v=>"1800" },
#{ p=>"4 Hours", v=>"14400" },

#{ p=>"10:00am PDT", v=>"10" },
#{ p=>"10:00pm PDT", v=>"22" },
#{ p=>"11:00am PDT", v=>"11" },
#{ p=>"11:00pm PDT", v=>"23" },
#{ p=>"12:00am PDT (Midnight)", v=>"24" },
#{ p=>"12:00pm PDT (Noon)", v=>"12" },
#{ p=>"1:00pm PDT", v=>"13" },
#{ p=>"2:00pm PDT", v=>"14" },
#{ p=>"3:00am PDT", v=>"3" },
#{ p=>"3:00pm PDT", v=>"15" },
#{ p=>"4:00am PDT", v=>"4" },
#{ p=>"4:00pm PDT", v=>"16" },
#{ p=>"5:00am PDT", v=>"5" },
#{ p=>"5:00pm PDT", v=>"17" },
#{ p=>"6:00am PDT", v=>"6" },
#{ p=>"6:00pm PDT", v=>"18" },
#{ p=>"7:00am PDT", v=>"7" },
#{ p=>"7:00pm PDT", v=>"19" },
#{ p=>"8:00am PDT", v=>"8" },
#{ p=>"8:00pm PDT", v=>"20" },
#{ p=>"9:00am PDT", v=>"9" },
#{ p=>"9:00pm PDT", v=>"21" },


##
## note: USERNAME is optional (when we're dealing with specific overrides for flexedit) -- code not written yet.
##
sub is_valid {
	my ($attr,$USERNAME) = @_;

	if ($PRODUCT::FLEXEDIT::fields{$attr}) { return(1); }
	if ($attr =~ /^zoovy\:schedule_([a-z0-9]){1,4}$/) { return(1); }
	# zoovy:qtyprice_qpXX, zoovy:qtyprice_mpXX
	if ($attr =~ /^zoovy\:qtyprice_qp([a-z0-9]){1,2}$/) { return(1); }
	if ($attr =~ /^zoovy\:qtyprice_mp([a-z0-9]){1,2}$/) { return(1); }
	# zoovy:qtymin_mpXX, zoovy:qtyinc_mpXX
	if ($attr =~ /^zoovy\:qtyinc_mp([a-z0-9]){1,2}$/) { return(1); }
	if ($attr =~ /^zoovy\:qtymin_mp([a-z0-9]){1,2}$/) { return(1); }
	if ($attr =~ /^user\:([a-z][a-z0-9\_]*)$/) { return(1); }
	if ($USERNAME && ($attr =~ /^$USERNAME:/)) { return(1); } # anything USERNAME: is valid
	if ($USERNAME ne '') {
		my $gref = &ZWEBSITE::fetch_globalref($USERNAME);
		if (defined $gref->{'@flexedit'}) {
			foreach my $set (@{$gref->{'@flexedit'}}) {
				if ($set->{'id'} eq $attr) { return(1); }
				}
			}
		}

	return(0);
	}


%PRODUCT::FLEXEDIT::fields = (
	## AUTO GENERATED
#	'a:unitsreturn' => { 
#		title=>'Units Returned', type=>'textbox', 
#		},
#	'a:unitssold' => { 
#		title=>'Units Sold', type=>'textbox', 
#		},
#	'a:customerswaiting' => { 
#		title=>'Customers with notifications pending', type=>'textbox',  
#		},
#	'a:salesrank' => { 
#		title=>'Sales Composite Rank', type=>'textbox', 
#		},
#	'a:reviewrank' => { 
#		title=>'Reviews Composite Rank', type=>'textbox', 
#		},

#	'user:coin_year'=>{
#		title=>"Coin Year",
#		type=>"textbox",
#		},
#	'user:coin_mint'=>{
#		title=>"Coin Mint",
#		type=>"textbox",
#		},
#	'user:coin_denom'=>{
#		title=>"Coin Denomination",
#		type=>"textbox",
#		},
#	'user:coin_type'=>{
#		title=>"Coin Type",
#		type=>"textbox",
#		},
#	'user:coin_variety'=>{
#		title=>"Coin Variety",	
#		type=>"textbox",
#		},
#	'user:coin_grade'=>{
#		title=>"Coin Grade",	
#		type=>"textbox",
#		},
#	'user:coin_service'=>{
#		title=>"Coin Service",	
#		type=>"textbox",
#		},
#

#'amzrp:strategy' => { 'db'=>'AMZRP_STRATEGY', 'type'=>'strategy', 'sku'=>1, 'title'=>'Amazon Repricing Strategy' },
#'amzrp:min_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Amazon Repricing Minimum Sell Price' },
#'amzrp:min_ship' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Amazon Repricing Minimum Ship Price' },
#'amzrp:max_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Amazon Repricing Max Price' },
#'amzrp:state'=> { 'db'=>'AMZRP_IS', 'type'=>'rpstate', 'sku'=>1 },

#'buyrp:strategy' => { 'db'=>'BUYRP_STRATEGY', 'type'=>'strategy', 'sku'=>1, 'title'=>'Buy.com Repricing Strategy' },
#'buyrp:min_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Buy.com Repricing Minimum Sell Price' },
#'buyrp:min_ship' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Buy.com Repricing Minimum Ship Price' },
#'buyrp:max_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Buy.com Repricing Max Price' },
#'buyrp:state'=> { 'db'=>'BUYRP_IS', 'type'=>'rpstate', 'sku'=>1 },

#'ebayrp:strategy' => { 'db'=>'EBAYRP_STRATEGY', 'type'=>'strategy', 'sku'=>1, 'title'=>'eBay Repricing Strategy' },
#'ebayrp:min_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'eBay Repricing Minimum Sell Price' },
#'ebayrp:min_ship' => { 'type'=>'currency', 'sku'=>1, 'title'=>'eBay Repricing Minimum Ship Price' },
#'ebayrp:max_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'eBay Repricing Max Price' },
#'ebayrp:state'=> { 'db'=>'EBAYRP_IS', 'type'=>'rpstate', 'sku'=>1 },

#'goorp:strategy' => { 'db'=>'GOORP_STRATEGY', 'type'=>'strategy', 'sku'=>1, 'title'=>'Google Marketplace Repricing Strategy' },
#'goorp:min_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Google Marketplace Repricing Minimum Sell Price' },
#'goorp:min_ship' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Google Marketplace Repricing Minimum Ship Price' },
#'goorp:max_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'Google Marketplace Repricing Max Price' },
#'goorp:state'=> { 'db'=>'GOORP_IS', 'type'=>'rpstate', 'sku'=>1 },

#'usr1rp:strategy' => { 'db'=>'USR1RP_STRATEGY', 'type'=>'strategy', 'sku'=>1, 'title'=>'User Repricing Strategy' },
#'usr1rp:min_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'User Repricing Minimum Sell Price' },
#'usr1rp:min_ship' => { 'type'=>'currency', 'sku'=>1, 'title'=>'User Repricing Minimum Ship Price' },
#'usr1rp:max_price' => { 'type'=>'currency', 'sku'=>1, 'title'=>'User Repricing Max Price' },
#'usr1rp:state'=> { 'db'=>'USR1RP_IS', 'type'=>'rpstate', 'sku'=>1 },

'adwords:prefer_for_query' =>  { 'title' => 'One tag/term per line', 'type' => 'textarea' },
'adwords:grouping' =>  { 'title' => 'Adwords Grouping', 'type' => 'textbox', hint=>'http://www.google.com/support/merchants/bin/answer.py?answer=188479' },
'adwords:labels' =>  { 'title' => 'Adwords Labels', 'type' => 'textbox', hint=>'One per line.' },
'adwords:blocked' =>  { 'title' => 'Adwords Blocked', 'type' => 'boolean', hint=>'Should this product be blocked from Adwords.' },
'addthis:html' => {'title' => 'AddThis HTML','type'=>'textarea','hint'=>'just the html portion, not the script tag','row'=>'5','cols'=>'40'},
'addthis:pubid' => {'title'=>'AddThis public ID','type'=>'textbox','size'=>'20'},
'amz:asin' =>  { 'title'=>'Amazon ASIN for the product', 'popular'=>1, 'index'=>'asin', 'src' => '2bhip:A31-00', 'type' => 'asin', 'sku'=>1 },
'amz:catalog' =>  { 'title'=>'Amazon Catalog', 'type' => 'chooser/amzcatalog' },
# 'amz:category' =>  { 'src' => 'beltsdirect:320306', 'type' => 'legacy' },
# 'amz:conditionnotes' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'amz:digest' =>  { 'type' => 'digest' },
'amz:fba' =>  { 'on' => 1, 'off' => 0, 'title' => 'Fulfilled By Amazon (FBA)', 'type' => 'cb' },
# 'amz:fulfillment' =>  { 'src' => 'dinkysduds:AG10', 'type' => 'legacy' },
'amz:grp_varkey' =>  { 'hint' => 'This is the variation keyword that represents the group on Amazon. For example, "APPAREL: Color". This field should be set on both the parent and children.', 'title' => 'Group Variation Keyword', 'type' => 'text' },
'amz:grp_varkey_value' =>  { 'src' => 'barefoottess:BFT-SPICE-RED', 'type' => 'legacy' },
'amz:grp_varvalue' =>  { 'hint' => 'This is the name of this option when displayed on Amazon. For example, you would not want to display the entire product name when the "Black Suede Boots" are on Amazon. You would simply show the choice "Black". This field should be set on the child products.', 'title' => 'Group Variation Keyword Value', 'type' => 'text' },
'amz:item_type' =>  { 'src' => 'amphidex:AR_223932', 'type' => 'legacy' },
'amz:key_feature' =>  { 'src' => 'buystonesonline:ABSOLUTEBLACK61', 'type' => 'legacy' },
'amz:key_features' =>  { 'hint' => 'Bulleted list sent to Amazon.', 'title' => 'Amazon Key Features', 'type' => 'textarea', 'rows' => 4, 'cols' => 50 },
'amz:search_terms' => { 'type'=>'chooser/amzsearchterms' },
'amz:thesaurus' => { 'type'=>'chooser/amzthesaurus' },


## special amz:prod_ fields
'amz:prod_desc' =>  { 'hint' => 'Used instead of Zoovy defined product description.', 'title' => 'Amazon Product Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 50 },
## re: amz:prod_image1 https://admin.zoovy.com/support/index.cgi?ACTION=VIEWTICKET&TICKET=2030159&USERNAME=summitfashions
'amz:prod_image1' =>  { 'sku'=>1, 'hint'=>'Used instead of Zoovy product image1', 'title' => 'Amazon Product Image 1', 'type' => 'image' },
'amz:prod_image2' =>  { 'sku'=>1, 'hint'=>'Used instead of Zoovy product image2', 'title' => 'Amazon Product Image 2', 'type' => 'image' },
'amz:prod_image3' =>  { 'sku'=>1, 'hint'=>'Used instead of Zoovy product image3', 'title' => 'Amazon Product Image 3', 'type' => 'image' },
'amz:prod_image4' =>  { 'hint' => 'Used instead of Zoovy product image4', 'title' => 'Amazon Product Image 4', 'type' => 'image' },
'amz:prod_image5' =>  { 'hint' => 'Used instead of Zoovy product image5', 'title' => 'Amazon Product Image 5', 'type' => 'image' },
'amz:prod_image6' =>  { 'hint' => 'Used instead of Zoovy product image6', 'title' => 'Amazon Product Image 6', 'type' => 'image' },
'amz:prod_image7' =>  { 'hint' => 'Used instead of Zoovy product image7', 'title' => 'Amazon Product Image 7', 'type' => 'image' },
'amz:prod_image8' =>  { 'hint' => 'Used instead of Zoovy product image8', 'title' => 'Amazon Product Image 8', 'type' => 'image' },
'amz:prod_image9' =>  { 'hint' => 'Used instead of Zoovy product image9', 'title' => 'Amazon Product Image 9', 'type' => 'image' },
'amz:prod_name' =>  { 'maxlength' => 200, 'hint' => 'Used instead of Zoovy defined product name.', 'title' => 'Amazon Product Title', 'type' => 'text', 'size' => 60 },
'amz:prod_size' => {  'ns' => 'product', 'hint' => 'Used when the product is only available in 1 size', 'amz-format' => 'Text', 'type' => 'textbox', 'title' => 'Amazon Product Size' },
'amz:prod_color' => {  'ns' => 'product', 'hint' => 'Used when the product is only available in 1 color', 'amz-format' => 'Text', 'type' => 'textbox', 'title' => 'Amazon Product Color' },
'amz:prod_condition' =>  { 'options' => [ { 'p' => 'New', 'v' => 'New' }, { 'p' => 'Refurbished', 'v' => 'Refurbished' }, { 'p' => 'UsedLikeNew', 'v' => 'UsedLikeNew' }, { 'p' => 'UsedVeryGood', 'v' => 'UsedVeryGood' }, { 'p' => 'UsedGood', 'v' => 'UsedGood' }, { 'p' => 'UsedAcceptable', 'v' => 'UsedAcceptable' }  ], 'title' => 'Amazon Condition', 'type' => 'select' },
## DYNAMIC AMAZON FIELDS ## (generated by /httpd/static/definitions/amz/20111123-validfields.pl)
'amz:prod_aa_aamisc_amperage' => { 'src' => 'amz.autopart.autoaccessorymisc.json', 'amz-units' => 'amps', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Amperage' },
'amz:prod_aa_aamisc_clrmap' => { 'ns' => 'product', 'xmlattrib' => 'ColorMap', 'amz-format' => 'ColorSpecification', 'src' => 'amz.autopart.autoaccessorymisc.json', 'title' => 'Color Map', 'type' => 'textbox' },
'amz:prod_aa_aamisc_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.autopart.autoaccessorymisc.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_aa_aamisc_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.autopart.autoaccessorymisc.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_aa_aamisc_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.autopart.autoaccessorymisc.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_aa_aamisc_viscosity' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.autopart.autoaccessorymisc.json', 'title' => 'Viscosity', 'type' => 'textbox' },
'amz:prod_aa_aamisc_voltage' => { 'src' => 'amz.autopart.autoaccessorymisc.json', 'amz-units' => 'volts', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'number', 'title' => 'Voltage' },
'amz:prod_aa_aamisc_volume' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.autopart.autoaccessorymisc.json', 'title' => 'Volume', 'type' => 'textbox' },
'amz:prod_aa_aamisc_wattage' => { 'src' => 'amz.autopart.autoaccessorymisc.json', 'amz-units' => 'watts', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'number', 'title' => 'Wattage' },
'amz:prod_base_systemreqs' => { 'ns' => 'product', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'System Requirements', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_ces_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_ce_ces_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_ce_ces_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.ce.consumerelectronics.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_ce_ces_colorscreen' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Color Screen', 'type' => 'checkbox' },
'amz:prod_ce_ces_computermemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Computer Memory Type', 'type' => 'textlist' },
'amz:prod_ce_ces_computermemorytype_10' => { 'ns' => 'product', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Computer Memory Type_10', 'type' => 'textbox' },
'amz:prod_ce_ces_digitalaudiocapacity' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Digital Audio Capacity', 'type' => 'textbox' },
'amz:prod_ce_ces_digitalmediaformat' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Digital Media Format', 'type' => 'textbox' },
'amz:prod_ce_ces_harddriveinterface' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Hard Drive Interface', 'type' => 'textlist' },
'amz:prod_ce_ces_harddrivesize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Hard Drive Size', 'type' => 'textlist' },
'amz:prod_ce_ces_holdercapacity' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Holder Capacity', 'type' => 'textbox' },
'amz:prod_ce_ces_homeautomationcmtnsdv' => { 'ns' => 'product', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Home Automation Communication Device', 'type' => 'textbox' },
'amz:prod_ce_ces_hwpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Hardware Platform', 'type' => 'textbox' },
'amz:prod_ce_ces_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_ce_ces_memoryslotsavailable' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Memory Slots Available', 'type' => 'textbox' },
'amz:prod_ce_ces_os' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Operating System', 'type' => 'textlist' },
'amz:prod_ce_ces_pdabasemdl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'P D A Base Model', 'type' => 'textlist' },
'amz:prod_ce_ces_powersource' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Power Source', 'type' => 'textbox' },
'amz:prod_ce_ces_ramsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'R A M Size', 'type' => 'textbox' },
'amz:prod_ce_ces_screenresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Screen Resolution', 'type' => 'textbox' },
'amz:prod_ce_ces_screensize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'ScreenSize', 'type' => 'number' },
'amz:prod_ce_ces_speakerdiameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'SpeakerDiameter', 'type' => 'number' },
'amz:prod_ce_ces_telephonetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Telephone Type', 'type' => 'textlist' },
'amz:prod_ce_ces_vehiclespeakersize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Vehicle Speaker Size', 'type' => 'textbox' },
'amz:prod_ce_ces_voltage' => { 'src' => 'amz.ce.consumerelectronics.json', 'amz-units' => 'volts', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Voltage' },
'amz:prod_ce_ces_wattage' => { 'src' => 'amz.ce.consumerelectronics.json', 'amz-units' => 'watts', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Wattage' },
'amz:prod_ce_ces_wrlstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.consumerelectronics.json', 'title' => 'Wireless Type', 'type' => 'textlist' },
'amz:prod_ce_gfxcard_gfxcarddscrpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Graphics Card Description', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_gfxcard_gfxcardinterface' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Graphics Card Interface', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_gfxcard_gfxcardramsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pc.json', 'title' => 'Graphics Card Ram Size', 'type' => 'textbox' },
'amz:prod_ce_pc_addldrives' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Additional Drives', 'type' => 'textlist' },
'amz:prod_ce_pc_addldrives_10' => { 'ns' => 'product', 'src' => 'amz.ce.pc.json', 'title' => 'Additional Drives_10', 'type' => 'textbox' },
'amz:prod_ce_pc_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_ce_pc_computermemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Computer Memory Type', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_ce_pc_computermemorytype_10' => { 'ns' => 'product', 'src' => 'amz.ce.pc.json', 'title' => 'Computer Memory Type_10', 'type' => 'textbox' },
'amz:prod_ce_pc_harddriveinterface' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Hard Drive Interface', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_ce_pc_harddrivesize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pc.json', 'title' => 'Hard Drive Size', 'type' => 'textlist' },
'amz:prod_ce_pc_hwpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Hardware Platform', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_pc_memoryslotsavailable' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Memory Slots Available', 'type' => 'textbox' },
'amz:prod_ce_pc_os' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Operating System', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_ce_pc_processorbrand' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Processor Brand', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_pc_processorcnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'ProcessorCount', 'type' => 'number' },
'amz:prod_ce_pc_processorspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Processor Speed', 'type' => 'textbox' },
'amz:prod_ce_pc_processortype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Processor Type', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_pc_ramsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pc.json', 'title' => 'R A M Size', 'type' => 'textbox' },
'amz:prod_ce_pc_screenresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Screen Resolution', 'type' => 'textbox' },
'amz:prod_ce_pc_screensize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pc.json', 'title' => 'ScreenSize', 'type' => 'number' },
'amz:prod_ce_pc_softwareincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Software Included', 'type' => 'textbox' },
'amz:prod_ce_pc_u-racksize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '1', 'v' => '1' },{ 'p' => '2', 'v' => '2' },{ 'p' => '3', 'v' => '3' },{ 'p' => '4', 'v' => '4' } ], 'src' => 'amz.ce.pc.json', 'type' => 'select', 'title' => 'P C U - Rack Size', 'list' => 'LIST_ELECTRONIX_PC_U-RACKSIZE' },
'amz:prod_ce_pc_wrlstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pc.json', 'title' => 'Wireless Type', 'type' => 'textlist' },
'amz:prod_ce_pda_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_ce_pda_colorscreen' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Color Screen', 'type' => 'checkbox' },
'amz:prod_ce_pda_computermemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Computer Memory Type', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_ce_pda_computermemorytype_10' => { 'ns' => 'product', 'src' => 'amz.ce.pda.json', 'title' => 'Computer Memory Type_10', 'type' => 'textbox' },
'amz:prod_ce_pda_harddrivesize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pda.json', 'title' => 'Hard Drive Size', 'type' => 'textbox' },
'amz:prod_ce_pda_memoryslotsavailable' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Memory Slots Available', 'type' => 'textbox' },
'amz:prod_ce_pda_os' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Operating System', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_ce_pda_pdabasemdl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'P D A Base Model', 'type' => 'textlist' },
'amz:prod_ce_pda_processorspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Processor Speed', 'type' => 'textbox' },
'amz:prod_ce_pda_processortype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Processor Type', 'type' => 'textbox' },
'amz:prod_ce_pda_ramsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pda.json', 'title' => 'R A M Size', 'type' => 'textbox' },
'amz:prod_ce_pda_romsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pda.json', 'title' => 'R O M Size', 'type' => 'textbox' },
'amz:prod_ce_pda_screenresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Screen Resolution', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_ce_pda_screensize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.ce.pda.json', 'title' => 'ScreenSize', 'type' => 'number' },
'amz:prod_ce_pda_softwareincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Software Included', 'type' => 'textbox' },
'amz:prod_ce_pda_wrlstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.ce.pda.json', 'title' => 'Wireless Type', 'type' => 'textlist' },
'amz:prod_cloth_cd_apparel-closure-type' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'apparel closure type', 'type' => 'textbox' },
'amz:prod_cloth_cd_apparelclosuretype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Round Classic Ring', 'v' => 'Round Classic Ring' },{ 'p' => 'Square Classic Ring', 'v' => 'Square Classic Ring' },{ 'p' => 'Flat Solid Buckle', 'v' => 'Flat Solid Buckle' },{ 'p' => 'D Ring', 'v' => 'D Ring' },{ 'p' => 'Double D Ring', 'v' => 'Double D Ring' },{ 'p' => 'Hook & Eye', 'v' => 'Hook & Eye' },{ 'p' => 'Snaps', 'v' => 'Snaps' },{ 'p' => 'Zipper', 'v' => 'Zipper' },{ 'p' => 'Button Fly', 'v' => 'Button Fly' },{ 'p' => 'Pull On', 'v' => 'Pull On' },{ 'p' => 'Drawstring', 'v' => 'Drawstring' },{ 'p' => 'Elastic', 'v' => 'Elastic' },{ 'p' => 'Velcro', 'v' => 'Velcro' },{ 'p' => 'Self Tie', 'v' => 'Self Tie' },{ 'p' => 'Velcro', 'v' => 'Velcro' },{ 'p' => 'J-Clip', 'v' => 'J-Clip' },{ 'p' => 'Button-End', 'v' => 'Button-End' },{ 'p' => 'Snap On', 'v' => 'Snap On' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'apparel-closure-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'apparel closure type' },
'amz:prod_cloth_cd_belt-style' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'belt style', 'type' => 'textbox' },
'amz:prod_cloth_cd_beltlength' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Belt Length', 'type' => 'textbox' },
'amz:prod_cloth_cd_beltstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Chain', 'v' => 'Chain' },{ 'p' => 'Sash/Woven', 'v' => 'Sash/Woven' },{ 'p' => 'Skinny', 'v' => 'Skinny' },{ 'p' => 'Medium ', 'v' => 'Medium ' },{ 'p' => 'Wide', 'v' => 'Wide' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'belt-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Belt Style' },
'amz:prod_cloth_cd_beltwidth' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Belt Width', 'type' => 'textbox' },
'amz:prod_cloth_cd_bottom-style' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'bottom style', 'type' => 'textbox' },
'amz:prod_cloth_cd_bottomstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Pant', 'v' => 'Pant' },{ 'p' => 'Short', 'v' => 'Short' },{ 'p' => 'Bikini', 'v' => 'Bikini' },{ 'p' => 'Thong', 'v' => 'Thong' },{ 'p' => 'G-String', 'v' => 'G-String' },{ 'p' => 'Boy Short', 'v' => 'Boy Short' },{ 'p' => 'Hipster', 'v' => 'Hipster' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'bottom-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'bottom style' },
'amz:prod_cloth_cd_brabandsize' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Bra Band Size', 'type' => 'textbox' },
'amz:prod_cloth_cd_buttonqty' => { 'ns' => 'product', 'amz-attr' => 'button-quantity', 'amz-format' => 'Text', 'src' => 'amz.clothing.json', 'type' => 'textbox', 'title' => 'Button Quantity' },
'amz:prod_cloth_cd_chestsize' => { 'ns' => 'product', 'amz-attr' => 'chest-size', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Chest Size', 'type' => 'textbox' },
'amz:prod_cloth_cd_clothingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'SocksHosiery', 'v' => 'SocksHosiery' },{ 'p' => 'Underwear', 'v' => 'Underwear' },{ 'p' => 'Bra', 'v' => 'Bra' },{ 'p' => 'Shoes', 'v' => 'Shoes' },{ 'p' => 'Hat', 'v' => 'Hat' },{ 'p' => 'Bag', 'v' => 'Bag' },{ 'p' => 'Accessory', 'v' => 'Accessory' },{ 'p' => 'Jewelry', 'v' => 'Jewelry' },{ 'p' => 'Sleepwear', 'v' => 'Sleepwear' },{ 'p' => 'Swimwear', 'v' => 'Swimwear' },{ 'p' => 'PersonalBodyCare', 'v' => 'PersonalBodyCare' },{ 'p' => 'HomeAccessory', 'v' => 'HomeAccessory' },{ 'p' => 'NonApparelMisc', 'v' => 'NonApparelMisc' } ], 'src' => 'amz.apparel.json', 'type' => 'select', 'title' => 'Clothing Clothing Type', 'list' => 'LIST_APPAREL_CLOTHING_CLOTHINGTYPE' },
'amz:prod_cloth_cd_collar-type' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'collar type', 'type' => 'textbox' },
'amz:prod_cloth_cd_collartype' => { 'amz-attr' => 'collar-type', 'ns' => 'product', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Mandarin Collar', 'v' => 'Mandarin Collar' },{ 'p' => 'Spread', 'v' => 'Spread' },{ 'p' => 'Cutaway', 'v' => 'Cutaway' },{ 'p' => 'Point', 'v' => 'Point' },{ 'p' => 'Button-Down', 'v' => 'Button-Down' } ], 'src' => 'amz.clothing.json', 'title' => 'collar type', 'type' => 'select' },
'amz:prod_cloth_cd_colormap' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Beige', 'v' => 'Beige' },{ 'p' => 'Black', 'v' => 'Black' },{ 'p' => 'Blue', 'v' => 'Blue' },{ 'p' => 'Bronze', 'v' => 'Bronze' },{ 'p' => 'Brown', 'v' => 'Brown' },{ 'p' => 'Gold', 'v' => 'Gold' },{ 'p' => 'Green', 'v' => 'Green' },{ 'p' => 'Grey', 'v' => 'Grey' },{ 'p' => 'Metallic', 'v' => 'Metallic' },{ 'p' => 'Multi', 'v' => 'Multi' },{ 'p' => 'Off-White', 'v' => 'Off-White' },{ 'p' => 'Orange', 'v' => 'Orange' },{ 'p' => 'Pink', 'v' => 'Pink' },{ 'p' => 'Purple', 'v' => 'Purple' },{ 'p' => 'Red', 'v' => 'Red' },{ 'p' => 'Silver', 'v' => 'Silver' },{ 'p' => 'Transparent', 'v' => 'Transparent' },{ 'p' => 'Turquoise', 'v' => 'Turquoise' },{ 'p' => 'White', 'v' => 'White' },{ 'p' => 'Yellow', 'v' => 'Yellow' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'color-map', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Color Map' },
'amz:prod_cloth_cd_ctrltype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Light', 'v' => 'Light' },{ 'p' => 'Medium', 'v' => 'Medium' },{ 'p' => 'Maximum', 'v' => 'Maximum' },{ 'p' => 'Moderate', 'v' => 'Moderate' },{ 'p' => 'Firm', 'v' => 'Firm' },{ 'p' => 'Extra Firm', 'v' => 'Extra Firm' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'control-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Control Type' },
'amz:prod_cloth_cd_ctryoforgn' => { 'ns' => 'product', 'maxlength' => '2', 'src' => 'amz.apparel.json', 'title' => 'Country of Origin', 'type' => 'textbox' },
'amz:prod_cloth_cd_cufftype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'French', 'v' => 'French' },{ 'p' => 'Barrel', 'v' => 'Barrel' },{ 'p' => 'Single', 'v' => 'Single' },{ 'p' => 'Cuffed', 'v' => 'Cuffed' },{ 'p' => 'Convertible', 'v' => 'Convertible' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'cuff-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Cuff Type' },
'amz:prod_cloth_cd_cupsize' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'A', 'v' => 'A' },{ 'p' => 'B', 'v' => 'B' },{ 'p' => 'C', 'v' => 'C' },{ 'p' => 'D', 'v' => 'D' },{ 'p' => 'DD', 'v' => 'DD' },{ 'p' => 'DDD', 'v' => 'DDD' },{ 'p' => 'E', 'v' => 'E' },{ 'p' => 'F', 'v' => 'F' },{ 'p' => 'FF', 'v' => 'FF' },{ 'p' => 'G', 'v' => 'G' },{ 'p' => 'H', 'v' => 'H' },{ 'p' => 'I', 'v' => 'I' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'cup-size', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Clothing Cup Size', 'list' => 'LIST_APPAREL_CLOTHING_CUPSIZE' },
'amz:prod_cloth_cd_dpt' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mens', 'v' => 'mens' },{ 'p' => 'womens', 'v' => 'womens' },{ 'p' => 'boys', 'v' => 'boys' },{ 'p' => 'girls', 'v' => 'girls' },{ 'p' => 'baby-boys', 'v' => 'baby-boys' },{ 'p' => 'baby-girls', 'v' => 'baby-girls' },{ 'p' => 'unisex-adult', 'v' => 'unisex-adult' },{ 'p' => 'unisex-child', 'v' => 'unisex-child' },{ 'p' => 'unisex-baby', 'v' => 'unisex-baby' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'department', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Department', 'amz-max-length' => 49 },
'amz:prod_cloth_cd_eventkwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.apparel.json', 'title' => 'Event Keywords', 'type' => 'textlist' },
'amz:prod_cloth_cd_fabricwash' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Light', 'v' => 'Light' },{ 'p' => 'Medium', 'v' => 'Medium' },{ 'p' => 'Dark', 'v' => 'Dark' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'fabric-wash', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Fabric Wash' },
'amz:prod_cloth_cd_fittype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Slim', 'v' => 'Slim' },{ 'p' => 'Regular', 'v' => 'Regular' },{ 'p' => 'Relaxed', 'v' => 'Relaxed' },{ 'p' => 'Stretch', 'v' => 'Stretch' },{ 'p' => 'Skinny', 'v' => 'Skinny' },{ 'p' => 'Loose', 'v' => 'Loose' },{ 'p' => 'Western', 'v' => 'Western' },{ 'p' => 'Overall', 'v' => 'Overall' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'fit-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Fit Type' },
'amz:prod_cloth_cd_frontpltype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Pleated', 'v' => 'Pleated' },{ 'p' => 'Flat Front', 'v' => 'Flat Front' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'front-pleat-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Front Pleat Type' },
'amz:prod_cloth_cd_heelheight' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Heel Height', 'type' => 'textbox' },
'amz:prod_cloth_cd_heeltype' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Heel Type', 'type' => 'textbox' },
'amz:prod_cloth_cd_innermaterial' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Inner Material', 'type' => 'textbox' },
'amz:prod_cloth_cd_inseamlength' => { 'ns' => 'product', 'amz-attr' => 'inseam-length', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Inseam Length', 'type' => 'textbox' },
'amz:prod_cloth_cd_iscstmz' => { 'ns' => 'product', 'amz-format' => 'Boolean', 'src' => 'amz.apparel.json', 'title' => 'Is Customizable', 'type' => 'checkbox' },
'amz:prod_cloth_cd_itemrise' => { 'amz-attr' => 'item-rise', 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Item Rise', 'type' => 'textbox' },
'amz:prod_cloth_cd_itemtype' => { 'ns' => 'product', 'amz-attr' => 'item-type', 'src' => 'amz.clothing.json', 'type' => 'textbox', 'title' => 'Item Type' },
'amz:prod_cloth_cd_legdiameter' => { 'amz-attr' => 'leg-diameter', 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Leg Diameter', 'type' => 'textbox' },
'amz:prod_cloth_cd_legstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Skinny ', 'v' => 'Skinny ' },{ 'p' => 'Tapered', 'v' => 'Tapered' },{ 'p' => 'Straight', 'v' => 'Straight' },{ 'p' => 'Boot Cut', 'v' => 'Boot Cut' },{ 'p' => 'Flared', 'v' => 'Flared' },{ 'p' => 'Trouser ', 'v' => 'Trouser ' },{ 'p' => 'Cropped', 'v' => 'Cropped' },{ 'p' => 'Ankle', 'v' => 'Ankle' },{ 'p' => 'Wide', 'v' => 'Wide' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'leg-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Leg Style' },
'amz:prod_cloth_cd_lenscolor' => { 'ns' => 'product', 'amz-attr' => 'LensColor','amz-format' => 'Text', 'src' => 'amz.eyewear.json','title' => 'Lens Title', 'type' => 'textbox' },
'amz:prod_cloth_cd_lenswidth' => { 'ns' => 'product', 'amz-attr' => 'LensWidth','amz-format' => 'Length', 'src' => 'amz.eyewear.json','title' => 'Lens Width', 'type' => 'textbox' },
'amz:prod_cloth_cd_materialopacity' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Ultra Sheer', 'v' => 'Ultra Sheer' },{ 'p' => 'Sheer', 'v' => 'Sheer' },{ 'p' => 'Semi Opaque', 'v' => 'Semi Opaque' },{ 'p' => 'Opaque', 'v' => 'Opaque' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'material-opacity', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Material Opacity' },
'amz:prod_cloth_cd_matlandfabric' => { 'ns' => 'product', 'amz-attr' => 'material-and-fabric', 'amz-format' => 'Text', 'src' => 'amz.clothing.json', 'title' => 'Material And Fabric', 'type' => 'textlist' },
'amz:prod_cloth_cd_necksize' => { 'ns' => 'product', 'amz-attr' => 'neck-size', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Neck Size', 'type' => 'textbox' },
'amz:prod_cloth_cd_neckstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Boat Neck', 'v' => 'Boat Neck' },{ 'p' => 'Cowl Neck', 'v' => 'Cowl Neck' },{ 'p' => 'Crewneck', 'v' => 'Crewneck' },{ 'p' => 'Halter', 'v' => 'Halter' },{ 'p' => 'Henley', 'v' => 'Henley' },{ 'p' => 'High Neck', 'v' => 'High Neck' },{ 'p' => 'Hooded', 'v' => 'Hooded' },{ 'p' => 'Mock Neck', 'v' => 'Mock Neck' },{ 'p' => 'One Shoulder', 'v' => 'One Shoulder' },{ 'p' => 'Racer Back', 'v' => 'Racer Back' },{ 'p' => 'Scoop Neck', 'v' => 'Scoop Neck' },{ 'p' => 'Strapless/Tube', 'v' => 'Strapless/Tube' },{ 'p' => 'Turtleneck', 'v' => 'Turtleneck' },{ 'p' => 'V-Neck', 'v' => 'V-Neck' },{ 'p' => 'Eyelet', 'v' => 'Eyelet' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'neck-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Neck Style' },
'amz:prod_cloth_cd_occandlife' => { 'ns' => 'product', 'amz-attr' => 'occasion-and-lifestyle', 'amz-format' => 'Text', 'src' => 'amz.clothing.json', 'title' => 'Occasion And Lifestyle', 'type' => 'textbox' },
'amz:prod_cloth_cd_outermaterial' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Outer Material', 'type' => 'textbox' },
'amz:prod_cloth_cd_patternstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Checkered', 'v' => 'Checkered' },{ 'p' => 'Paisley', 'v' => 'Paisley' },{ 'p' => 'Patterned', 'v' => 'Patterned' },{ 'p' => 'Polka Dots', 'v' => 'Polka Dots' },{ 'p' => 'Solid', 'v' => 'Solid' },{ 'p' => 'Stripes', 'v' => 'Stripes' },{ 'p' => 'Plaid', 'v' => 'Plaid' },{ 'p' => 'String', 'v' => 'String' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'pattern-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Pattern Style' },
'amz:prod_cloth_cd_platinumkwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.apparel.json', 'title' => 'Platinum Keywords', 'type' => 'textlist', 'amz-max-length' => 49 },
'amz:prod_cloth_cd_pocketdesc' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Basic 5 Pckt', 'v' => 'Basic 5 Pckt' },{ 'p' => 'Pork Chop Pocket', 'v' => 'Pork Chop Pocket' },{ 'p' => 'Slant Pocket', 'v' => 'Slant Pocket' },{ 'p' => 'Utility Pocket', 'v' => 'Utility Pocket' },{ 'p' => 'Cargo', 'v' => 'Cargo' },{ 'p' => 'Carpenter', 'v' => 'Carpenter' },{ 'p' => 'Back Flap Pocket', 'v' => 'Back Flap Pocket' },{ 'p' => 'Slit Pocket', 'v' => 'Slit Pocket' },{ 'p' => 'No Back Pocket', 'v' => 'No Back Pocket' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'pocket-description', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Pocket Description' },
'amz:prod_cloth_cd_risestyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'No Show', 'v' => 'No Show' },{ 'p' => 'Ankle', 'v' => 'Ankle' },{ 'p' => 'Mid-Calf', 'v' => 'Mid-Calf' },{ 'p' => 'Knee High', 'v' => 'Knee High' },{ 'p' => 'Thigh High', 'v' => 'Thigh High' },{ 'p' => 'Low', 'v' => 'Low' },{ 'p' => 'Mid', 'v' => 'Mid' },{ 'p' => 'High', 'v' => 'High' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'rise-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Rise Style' },
'amz:prod_cloth_cd_shaftheight' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Shaft Height', 'type' => 'textbox' },
'amz:prod_cloth_cd_shoeclstype' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Shoe Closure Type', 'type' => 'textbox' },
'amz:prod_cloth_cd_shoewidth' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'AAAA', 'v' => 'AAAA' },{ 'p' => 'AAA', 'v' => 'AAA' },{ 'p' => 'AA', 'v' => 'AA' },{ 'p' => 'A', 'v' => 'A' },{ 'p' => 'B', 'v' => 'B' },{ 'p' => 'C', 'v' => 'C' },{ 'p' => 'D', 'v' => 'D' },{ 'p' => 'E', 'v' => 'E' },{ 'p' => 'E', 'v' => 'E' },{ 'p' => 'EE', 'v' => 'EE' },{ 'p' => 'EEE', 'v' => 'EEE' },{ 'p' => 'EEEE', 'v' => 'EEEE' },{ 'p' => 'EEEEE', 'v' => 'EEEEE' } ], 'src' => 'amz.apparel.json', 'type' => 'select', 'title' => 'Clothing Shoe Width', 'list' => 'LIST_APPAREL_CLOTHING_SHOEWIDTH' },
'amz:prod_cloth_cd_sizemap' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'XXXXX-Small', 'v' => 'XXXXX-Small' },{ 'p' => 'XXXX-Small', 'v' => 'XXXX-Small' },{ 'p' => 'XXX-Small', 'v' => 'XXX-Small' },{ 'p' => 'XX-Small', 'v' => 'XX-Small' },{ 'p' => 'X-Small', 'v' => 'X-Small' },{ 'p' => 'Small', 'v' => 'Small' },{ 'p' => 'Medium', 'v' => 'Medium' },{ 'p' => 'Large', 'v' => 'Large' },{ 'p' => 'X-Large', 'v' => 'X-Large' },{ 'p' => 'XX-Large', 'v' => 'XX-Large' },{ 'p' => 'XXX-Large', 'v' => 'XXX-Large' },{ 'p' => 'XXXX-Large', 'v' => 'XXXX-Large' },{ 'p' => 'XXXXX-Large', 'v' => 'XXXXX-Large' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'size-map', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Clothing Size Map', 'list' => 'LIST_APPAREL_CLOTHING_SIZEMAP' },
'amz:prod_cloth_cd_sleeve-type' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'sleeve type', 'type' => 'textbox' },
'amz:prod_cloth_cd_sleevelength' => { 'ns' => 'product', 'amz-attr' => 'sleeve-length', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Sleeve Length', 'type' => 'textbox' },
'amz:prod_cloth_cd_sleevetype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Short Sleeve', 'v' => 'Short Sleeve' },{ 'p' => 'Long Sleeve', 'v' => 'Long Sleeve' },{ 'p' => 'Sleeveless', 'v' => 'Sleeveless' },{ 'p' => '3/4 Sleeve', 'v' => '3/4 Sleeve' },{ 'p' => 'Cap Sleeve', 'v' => 'Cap Sleeve' },{ 'p' => 'Tanks', 'v' => 'Tanks' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'sleeve-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'sleeve type' },
'amz:prod_cloth_cd_solematerial' => { 'ns' => 'product', 'src' => 'amz.apparel.json', 'title' => 'Sole Material', 'type' => 'textbox' },
'amz:prod_cloth_cd_specialfeature' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Carry-On', 'v' => 'Carry-On' },{ 'p' => 'Tsa Lock', 'v' => 'Tsa Lock' },{ 'p' => 'Tsa Ready', 'v' => 'Tsa Ready' },{ 'p' => 'Lightweight', 'v' => 'Lightweight' },{ 'p' => 'Checkpoint Friendly', 'v' => 'Checkpoint Friendly' },{ 'p' => 'Built In Scale', 'v' => 'Built In Scale' },{ 'p' => 'Reversible', 'v' => 'Reversible' },{ 'p' => 'Adjustable', 'v' => 'Adjustable' },{ 'p' => 'Wrinkle-Free', 'v' => 'Wrinkle-Free' },{ 'p' => 'Elastic Band', 'v' => 'Elastic Band' },{ 'p' => 'Sun Protection', 'v' => 'Sun Protection' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'special-feature1', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Special Feature' },
'amz:prod_cloth_cd_specialsizetype' => { 'ns' => 'product', 'amz-attr' => 'special-size-type', 'amz-format' => 'Text', 'src' => 'amz.clothing.json', 'title' => 'Special Size Type', 'type' => 'textlist' },
'amz:prod_cloth_cd_straptype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Strapless', 'v' => 'Strapless' },{ 'p' => 'Invisible', 'v' => 'Invisible' },{ 'p' => 'Convertible', 'v' => 'Convertible' },{ 'p' => 'Halter', 'v' => 'Halter' },{ 'p' => 'Racerback', 'v' => 'Racerback' },{ 'p' => 'Backless', 'v' => 'Backless' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'strap-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Strap Type' },
'amz:prod_cloth_cd_stylekwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.apparel.json', 'title' => 'Style Keywords', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_cloth_cd_stylename' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Full Coverage', 'v' => 'Full Coverage' },{ 'p' => 'Demi', 'v' => 'Demi' },{ 'p' => 'Balconette', 'v' => 'Balconette' },{ 'p' => 'Plunge', 'v' => 'Plunge' },{ 'p' => 'Push-Up', 'v' => 'Push-Up' },{ 'p' => 'Seamless', 'v' => 'Seamless' },{ 'p' => 'Padded', 'v' => 'Padded' },{ 'p' => 'Molded', 'v' => 'Molded' },{ 'p' => 'Soft', 'v' => 'Soft' },{ 'p' => 'Double-Breasted', 'v' => 'Double-Breasted' },{ 'p' => 'Classic', 'v' => 'Classic' },{ 'p' => 'Modern/Fitted', 'v' => 'Modern/Fitted' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'style-name', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Style Name' },
'amz:prod_cloth_cd_theme' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Animal', 'v' => 'Animal' },{ 'p' => 'Cartoon', 'v' => 'Cartoon' },{ 'p' => 'Classic Monster', 'v' => 'Classic Monster' },{ 'p' => 'Fairytale', 'v' => 'Fairytale' },{ 'p' => 'Famous People', 'v' => 'Famous People' },{ 'p' => 'Food & Beverage', 'v' => 'Food & Beverage' },{ 'p' => 'Historical & Period', 'v' => 'Historical & Period' },{ 'p' => 'Horror', 'v' => 'Horror' },{ 'p' => 'Humorous', 'v' => 'Humorous' },{ 'p' => 'Insects', 'v' => 'Insects' },{ 'p' => 'Mascots', 'v' => 'Mascots' },{ 'p' => 'Occupational/Professional', 'v' => 'Occupational/Professional' },{ 'p' => 'Religious', 'v' => 'Religious' },{ 'p' => 'Scary', 'v' => 'Scary' },{ 'p' => 'Science Fiction', 'v' => 'Science Fiction' },{ 'p' => 'Sexy', 'v' => 'Sexy' },{ 'p' => 'Sports', 'v' => 'Sports' },{ 'p' => 'Superhero', 'v' => 'Superhero' },{ 'p' => 'Tv & Movies', 'v' => 'Tv & Movies' },{ 'p' => 'Western', 'v' => 'Western' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'theme', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Theme' },
'amz:prod_cloth_cd_topstyle' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Strapless/Tube', 'v' => 'Strapless/Tube' },{ 'p' => 'Halter', 'v' => 'Halter' },{ 'p' => 'Tank', 'v' => 'Tank' },{ 'p' => 'Racerback', 'v' => 'Racerback' },{ 'p' => 'Cami', 'v' => 'Cami' },{ 'p' => 'Button Down', 'v' => 'Button Down' },{ 'p' => 'One Shoulder', 'v' => 'One Shoulder' },{ 'p' => 'Bandeaux', 'v' => 'Bandeaux' },{ 'p' => 'Triangle Tops', 'v' => 'Triangle Tops' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'top-style', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Top Style' },
'amz:prod_cloth_cd_underwiretype' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Underwire', 'v' => 'Underwire' },{ 'p' => 'Wire Free', 'v' => 'Wire Free' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'underwire-type', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Underwire Type' },
'amz:prod_cloth_cd_waistsize' => { 'ns' => 'product', 'amz-attr' => 'waist-size', 'amz-format' => 'Measurement', 'src' => 'amz.clothing.json', 'title' => 'Waist Size', 'type' => 'textbox' },
'amz:prod_cloth_cd_waterreslevel' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'not_water_resistant', 'v' => 'not_water_resistant' },{ 'p' => 'water_resistant', 'v' => 'water_resistant' },{ 'p' => 'waterproof', 'v' => 'waterproof' } ], 'src' => 'amz.clothing.json', 'ns' => 'product', 'amz-attr' => 'water-resistance-level', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Water Resistance Level' },
'amz:prod_cp_bagcase_bagcasetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'binocular-cases', 'v' => 'binocular-cases' },{ 'p' => 'camcorder-cases', 'v' => 'camcorder-cases' },{ 'p' => 'camera-cases', 'v' => 'camera-cases' },{ 'p' => 'combination-cases', 'v' => 'combination-cases' },{ 'p' => 'electronic-equipment-cases', 'v' => 'electronic-equipment-cases' },{ 'p' => 'filter-cases', 'v' => 'filter-cases' },{ 'p' => 'lens-cases', 'v' => 'lens-cases' },{ 'p' => 'lighting-cases', 'v' => 'lighting-cases' },{ 'p' => 'projection-cases', 'v' => 'projection-cases' },{ 'p' => 'scope-cases', 'v' => 'scope-cases' },{ 'p' => 'stand-cases', 'v' => 'stand-cases' },{ 'p' => 'system-cases', 'v' => 'system-cases' },{ 'p' => 'telescope-cases', 'v' => 'telescope-cases' },{ 'p' => 'tripod-cases', 'v' => 'tripod-cases' },{ 'p' => 'light-meter-cases', 'v' => 'light-meter-cases' },{ 'p' => 'other-purpose-cases', 'v' => 'other-purpose-cases' } ], 'src' => 'amz.camera.bagcase.json', 'type' => 'select', 'title' => 'Bag Case Bag Case Type', 'list' => 'LIST_CAMERA_BAGCASE_BAGCASETYPE' },
'amz:prod_cp_bagcase_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'x-ray-protection', 'v' => 'x-ray-protection' },{ 'p' => 'weatherproof', 'v' => 'weatherproof' } ], 'src' => 'amz.camera.bagcase.json', 'type' => 'select', 'title' => 'Bag Case Features', 'list' => 'LIST_CAMERA_BAGCASE_FEATURES' },
'amz:prod_cp_bagcase_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'hard', 'v' => 'hard' },{ 'p' => 'soft', 'v' => 'soft' },{ 'p' => 'air', 'v' => 'air' },{ 'p' => 'plastic', 'v' => 'plastic' },{ 'p' => 'metal', 'v' => 'metal' },{ 'p' => 'cloth', 'v' => 'cloth' } ], 'src' => 'amz.camera.bagcase.json', 'type' => 'select', 'title' => 'Bag Case Material Type', 'list' => 'LIST_CAMERA_BAGCASE_MATERIALTYPE' },
'amz:prod_cp_bagcase_specificuses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'travel', 'v' => 'travel' },{ 'p' => 'hiking-and-outdoors', 'v' => 'hiking-and-outdoors' },{ 'p' => 'hunting-and-shooting', 'v' => 'hunting-and-shooting' },{ 'p' => 'sports', 'v' => 'sports' } ], 'src' => 'amz.camera.bagcase.json', 'type' => 'select', 'title' => 'Bag Case Specific Uses', 'list' => 'LIST_CAMERA_BAGCASE_SPECIFICUSES' },
'amz:prod_cp_bagcase_style' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'backpacks', 'v' => 'backpacks' },{ 'p' => 'beltpacks', 'v' => 'beltpacks' },{ 'p' => 'briefcases', 'v' => 'briefcases' },{ 'p' => 'holster-style-cases', 'v' => 'holster-style-cases' },{ 'p' => 'portfolios', 'v' => 'portfolios' },{ 'p' => 'print-cases', 'v' => 'print-cases' },{ 'p' => 'roller-cases', 'v' => 'roller-cases' },{ 'p' => 'vests', 'v' => 'vests' },{ 'p' => 'wraps', 'v' => 'wraps' },{ 'p' => 'waist-style-cases', 'v' => 'waist-style-cases' },{ 'p' => 'compact-cases', 'v' => 'compact-cases' },{ 'p' => 'pouches', 'v' => 'pouches' } ], 'src' => 'amz.camera.bagcase.json', 'type' => 'select', 'title' => 'Bag Case Style', 'list' => 'LIST_CAMERA_BAGCASE_STYLE' },
'amz:prod_cp_binc_apparentangleofview' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Apparent Angle Of View', 'type' => 'textbox' },
'amz:prod_cp_binc_binoculartype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'binoculars', 'v' => 'binoculars' },{ 'p' => 'monoculars', 'v' => 'monoculars' },{ 'p' => 'laser-rangefinders', 'v' => 'laser-rangefinders' },{ 'p' => 'spotting-scopes', 'v' => 'spotting-scopes' },{ 'p' => 'night-vision', 'v' => 'night-vision' } ], 'src' => 'amz.camera.binocular.json', 'type' => 'select', 'title' => 'Binocular Binocular Type', 'list' => 'LIST_CAMERA_BINOCULAR_BINOCULARTYPE' },
'amz:prod_cp_binc_coating' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Coating', 'type' => 'textbox' },
'amz:prod_cp_binc_diopteradjustmentrange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Diopter Adjustment Range', 'type' => 'textbox' },
'amz:prod_cp_binc_exitpupildiameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.binocular.json', 'title' => 'ExitPupilDiameter', 'type' => 'number' },
'amz:prod_cp_binc_eyepiecelensconstrc' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Eyepiece Lens Construction', 'type' => 'textbox' },
'amz:prod_cp_binc_eyerelief' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'EyeRelief', 'type' => 'number' },
'amz:prod_cp_binc_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'compact', 'v' => 'compact' },{ 'p' => 'full-size', 'v' => 'full-size' },{ 'p' => 'image-stabilizing', 'v' => 'image-stabilizing' },{ 'p' => 'waterproof', 'v' => 'waterproof' },{ 'p' => 'fogproof', 'v' => 'fogproof' },{ 'p' => 'zoom', 'v' => 'zoom' },{ 'p' => 'uv-protection', 'v' => 'uv-protection' } ], 'src' => 'amz.camera.binocular.json', 'type' => 'select', 'title' => 'Binocular Features', 'list' => 'LIST_CAMERA_BINOCULAR_FEATURES' },
'amz:prod_cp_binc_fieldofview' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'FieldOfView', 'type' => 'number' },
'amz:prod_cp_binc_focustype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Focus Type', 'type' => 'textbox' },
'amz:prod_cp_binc_magnification' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Magnification', 'type' => 'textbox' },
'amz:prod_cp_binc_objectivelensconstrc' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Objective Lens Construction', 'type' => 'textbox' },
'amz:prod_cp_binc_objectivelensdiameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.binocular.json', 'title' => 'ObjectiveLensDiameter', 'type' => 'number' },
'amz:prod_cp_binc_prismtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Prism Type', 'type' => 'textbox' },
'amz:prod_cp_binc_realangleofview' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Real Angle Of View', 'type' => 'textbox' },
'amz:prod_cp_binc_specificuses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'tabletop', 'v' => 'tabletop' },{ 'p' => 'travel', 'v' => 'travel' },{ 'p' => 'hiking-and-outdoors', 'v' => 'hiking-and-outdoors' },{ 'p' => 'hunting-and-shooting', 'v' => 'hunting-and-shooting' },{ 'p' => 'sports', 'v' => 'sports' } ], 'src' => 'amz.camera.binocular.json', 'type' => 'select', 'title' => 'Binocular Specific Uses', 'list' => 'LIST_CAMERA_BINOCULAR_SPECIFICUSES' },
'amz:prod_cp_binc_tripodready' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.binocular.json', 'title' => 'Tripod Ready', 'type' => 'checkbox' },
'amz:prod_cp_blankmedia_analogformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '8mm-camcorder-tapes', 'v' => '8mm-camcorder-tapes' },{ 'p' => 'beta', 'v' => 'beta' },{ 'p' => 'hi-8-cassettes', 'v' => 'hi-8-cassettes' },{ 'p' => 's-vhs', 'v' => 's-vhs' },{ 'p' => 's-vhs-c', 'v' => 's-vhs-c' },{ 'p' => 'vhs', 'v' => 'vhs' },{ 'p' => 'vhs-c', 'v' => 'vhs-c' },{ 'p' => 'reel-tapes', 'v' => 'reel-tapes' } ], 'src' => 'amz.camera.blankmedia.json', 'type' => 'select', 'title' => 'Blank Media Analog Formats', 'list' => 'LIST_CAMERA_BLANKMEDIA_ANALOGFORMATS' },
'amz:prod_cp_blankmedia_cnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.blankmedia.json', 'title' => 'Count', 'type' => 'number' },
'amz:prod_cp_blankmedia_digitalformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'minidv-cassettes', 'v' => 'minidv-cassettes' },{ 'p' => 'full-size-dv-cassettes', 'v' => 'full-size-dv-cassettes' },{ 'p' => 'micromv', 'v' => 'micromv' },{ 'p' => 'dvd', 'v' => 'dvd' },{ 'p' => 'digital-beta-cassettes', 'v' => 'digital-beta-cassettes' } ], 'src' => 'amz.camera.blankmedia.json', 'type' => 'select', 'title' => 'Blank Media Digital Formats', 'list' => 'LIST_CAMERA_BLANKMEDIA_DIGITALFORMATS' },
'amz:prod_cp_blankmedia_mediacolor' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'unknown_chromatism', 'v' => 'unknown_chromatism' },{ 'p' => 'black-and-white', 'v' => 'black-and-white' },{ 'p' => 'color', 'v' => 'color' },{ 'p' => 'tinted', 'v' => 'tinted' },{ 'p' => 'colorized', 'v' => 'colorized' },{ 'p' => 'color/black_and_white', 'v' => 'color/black_and_white' } ], 'src' => 'amz.camera.blankmedia.json', 'type' => 'select', 'title' => 'Blank Media Media Color', 'list' => 'LIST_CAMERA_BLANKMEDIA_MEDIACOLOR' },
'amz:prod_cp_blankmedia_motionfilmformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '8mm-film', 'v' => '8mm-film' },{ 'p' => 'super-8mm-film', 'v' => 'super-8mm-film' },{ 'p' => '16mm-film', 'v' => '16mm-film' },{ 'p' => 'super-16mm-film', 'v' => 'super-16mm-film' },{ 'p' => '35mm-film', 'v' => '35mm-film' },{ 'p' => '65mm-film', 'v' => '65mm-film' },{ 'p' => '70mm-film', 'v' => '70mm-film' },{ 'p' => 'other-film-formats', 'v' => 'other-film-formats' } ], 'src' => 'amz.camera.blankmedia.json', 'type' => 'select', 'title' => 'Blank Media Motion Film Formats', 'list' => 'LIST_CAMERA_BLANKMEDIA_MOTIONFILMFORMATS' },
'amz:prod_cp_camcorder_acadapterincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'A C Adapter Included', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_analogformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'general', 'v' => 'general' },{ 'p' => '8mm', 'v' => '8mm' },{ 'p' => 'betacam-sp', 'v' => 'betacam-sp' },{ 'p' => 'hi-8', 'v' => 'hi-8' },{ 'p' => 's-vhs', 'v' => 's-vhs' },{ 'p' => 's-vhs-c', 'v' => 's-vhs-c' },{ 'p' => 'vhs', 'v' => 'vhs' },{ 'p' => 'vhs-c', 'v' => 'vhs-c' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Analog Formats', 'list' => 'LIST_CAMERA_CAMCORDER_ANALOGFORMATS' },
'amz:prod_cp_camcorder_audio' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'stereo', 'v' => 'stereo' },{ 'p' => 'mono', 'v' => 'mono' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Audio', 'list' => 'LIST_CAMERA_CAMCORDER_AUDIO' },
'amz:prod_cp_camcorder_autolight' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Autolight', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_avoutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'A V Output', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_batterytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Battery Type', 'type' => 'textbox' },
'amz:prod_cp_camcorder_computerplatform' => { 'ns' => 'product', 'amz-format' => 'ComputerPlatform', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'windows', 'v' => 'windows' },{ 'p' => 'mac', 'v' => 'mac' },{ 'p' => 'linux', 'v' => 'linux' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Computer Platform Type', 'list' => 'LIST_BASE_COMPUTERPLATFORM_TYPE' },
'amz:prod_cp_camcorder_digitalformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'general', 'v' => 'general' },{ 'p' => 'digital-betacam', 'v' => 'digital-betacam' },{ 'p' => 'dv', 'v' => 'dv' },{ 'p' => 'dvcam', 'v' => 'dvcam' },{ 'p' => 'dvcpro', 'v' => 'dvcpro' },{ 'p' => 'minidv', 'v' => 'minidv' },{ 'p' => 'micromv', 'v' => 'micromv' },{ 'p' => 'digital8', 'v' => 'digital8' },{ 'p' => 'dvd', 'v' => 'dvd' },{ 'p' => 'minidisc', 'v' => 'minidisc' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Digital Formats', 'list' => 'LIST_CAMERA_CAMCORDER_DIGITALFORMATS' },
'amz:prod_cp_camcorder_digitalstillcapability' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Digital Still Capability', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_digitalstillresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Digital Still Resolution', 'type' => 'textbox' },
'amz:prod_cp_camcorder_digitalzoom' => { 'src' => 'amz.camera.camcorder.json', 'amz-units' => 'x', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Digital Zoom' },
'amz:prod_cp_camcorder_externalmemoryincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'External Memory Included', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_externalmemorysize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.camcorder.json', 'title' => 'External Memory Size', 'type' => 'textbox' },
'amz:prod_cp_camcorder_externalmemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'memory-stick', 'v' => 'memory-stick' },{ 'p' => 'secure-digital', 'v' => 'secure-digital' },{ 'p' => 'mmc', 'v' => 'mmc' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder External Memory Type', 'list' => 'LIST_CAMERA_CAMCORDER_EXTERNALMEMORYTYPE' },
'amz:prod_cp_camcorder_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'lcd-screen', 'v' => 'lcd-screen' },{ 'p' => 'mpeg', 'v' => 'mpeg' },{ 'p' => 'digital-still', 'v' => 'digital-still' },{ 'p' => 'memory-card-compatible', 'v' => 'memory-card-compatible' },{ 'p' => 'image-stabilization', 'v' => 'image-stabilization' },{ 'p' => 'insert-edit', 'v' => 'insert-edit' },{ 'p' => 'underwater', 'v' => 'underwater' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Features', 'list' => 'LIST_CAMERA_CAMCORDER_FEATURES' },
'amz:prod_cp_camcorder_filmformats' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'general', 'v' => 'general' },{ 'p' => '8mm', 'v' => '8mm' },{ 'p' => '16mm', 'v' => '16mm' },{ 'p' => '35mm', 'v' => '35mm' },{ 'p' => '65mm', 'v' => '65mm' },{ 'p' => '70mm', 'v' => '70mm' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Film Formats', 'list' => 'LIST_CAMERA_CAMCORDER_FILMFORMATS' },
'amz:prod_cp_camcorder_firewireoutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Firewire Output', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_flyingeraseheads' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Flying Erase Heads', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_headphonejack' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Headphone Jack', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_hotshoe' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Hot Shoe', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_imagestabilization' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Image Stabilization', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_infraredcapability' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Infrared Capability', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_lcdscreensize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.camcorder.json', 'title' => 'LCDScreenSize', 'type' => 'number' },
'amz:prod_cp_camcorder_lcdswivel' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'L C D Swivel', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_lenstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'fixed-non-zoom', 'v' => 'fixed-non-zoom' },{ 'p' => 'fixed-zoom', 'v' => 'fixed-zoom' },{ 'p' => 'interchangeable', 'v' => 'interchangeable' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Lens Type', 'list' => 'LIST_CAMERA_CAMCORDER_LENSTYPE' },
'amz:prod_cp_camcorder_maxaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Max Aperture', 'type' => 'textbox' },
'amz:prod_cp_camcorder_minaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Min Aperture', 'type' => 'textbox' },
'amz:prod_cp_camcorder_mpegmoviemode' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mpeg', 'v' => 'mpeg' },{ 'p' => 'mpeg2', 'v' => 'mpeg2' },{ 'p' => 'mpeg4', 'v' => 'mpeg4' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder M P E G Movie Mode', 'list' => 'LIST_CAMERA_CAMCORDER_MPEGMOVIEMODE' },
'amz:prod_cp_camcorder_opticalzoom' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Optical Zoom', 'type' => 'textbox' },
'amz:prod_cp_camcorder_playbackformat' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'pal', 'v' => 'pal' },{ 'p' => 'ntsc', 'v' => 'ntsc' },{ 'p' => 'multisystem', 'v' => 'multisystem' },{ 'p' => 'secam', 'v' => 'secam' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Playback Format', 'list' => 'LIST_CAMERA_CAMCORDER_PLAYBACKFORMAT' },
'amz:prod_cp_camcorder_rechargeablebincld' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Rechargeable Battery Included', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_remoteincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Remote Included', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_s-videooutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'S - Video Output', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_sensortype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'ccd', 'v' => 'ccd' },{ 'p' => '3-chip-ccd', 'v' => '3-chip-ccd' },{ 'p' => 'cmos', 'v' => 'cmos' },{ 'p' => 'progressive-scan-ccd', 'v' => 'progressive-scan-ccd' },{ 'p' => 'fixed-zoom-lens', 'v' => 'fixed-zoom-lens' },{ 'p' => 'interchangeable-lens', 'v' => 'interchangeable-lens' },{ 'p' => 'other-lens', 'v' => 'other-lens' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Sensor Type', 'list' => 'LIST_CAMERA_CAMCORDER_SENSORTYPE' },
'amz:prod_cp_camcorder_softwareincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Software Included', 'type' => 'textbox' },
'amz:prod_cp_camcorder_usboutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'usb1.1', 'v' => 'usb1.1' },{ 'p' => 'usb2.0', 'v' => 'usb2.0' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder U S B Output', 'list' => 'LIST_CAMERA_CAMCORDER_USBOUTPUT' },
'amz:prod_cp_camcorder_usbstreaming' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'U S B Streaming', 'type' => 'checkbox' },
'amz:prod_cp_camcorder_videoresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.camcorder.json', 'title' => 'Video Resolution', 'type' => 'textbox' },
'amz:prod_cp_camcorder_viewfinder' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black-and-white', 'v' => 'black-and-white' },{ 'p' => 'color', 'v' => 'color' } ], 'src' => 'amz.camera.camcorder.json', 'type' => 'select', 'title' => 'Camcorder Viewfinder', 'list' => 'LIST_CAMERA_CAMCORDER_VIEWFINDER' },
'amz:prod_cp_cleaner_cleanertype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'brushes', 'v' => 'brushes' },{ 'p' => 'cloths', 'v' => 'cloths' },{ 'p' => 'cleaning-kits', 'v' => 'cleaning-kits' },{ 'p' => 'compressed-air', 'v' => 'compressed-air' },{ 'p' => 'liquid-cleaners', 'v' => 'liquid-cleaners' },{ 'p' => 'refills', 'v' => 'refills' } ], 'src' => 'amz.camera.cleaner.json', 'type' => 'select', 'title' => 'Cleaner Cleaner Type', 'list' => 'LIST_CAMERA_CLEANER_CLEANERTYPE' },
'amz:prod_cp_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_cp_dgc_acadapterincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'A C Adapter Included', 'type' => 'checkbox' },
'amz:prod_cp_dgc_audiorecording' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Audio Recording', 'type' => 'checkbox' },
'amz:prod_cp_dgc_autolight' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Autolight', 'type' => 'checkbox' },
'amz:prod_cp_dgc_avoutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'A V Output', 'type' => 'checkbox' },
'amz:prod_cp_dgc_batterytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Battery Type', 'type' => 'textbox' },
'amz:prod_cp_dgc_cameratype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'point-and-shoot', 'v' => 'point-and-shoot' },{ 'p' => 'slr', 'v' => 'slr' },{ 'p' => '3-d', 'v' => '3-d' },{ 'p' => 'macro', 'v' => 'macro' },{ 'p' => 'passport-and-id', 'v' => 'passport-and-id' },{ 'p' => 'underwater', 'v' => 'underwater' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Camera Type', 'list' => 'LIST_CAMERA_DIGITALCAMERA_CAMERATYPE' },
'amz:prod_cp_dgc_computerplatform' => { 'ns' => 'product', 'amz-format' => 'ComputerPlatform', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'windows', 'v' => 'windows' },{ 'p' => 'mac', 'v' => 'mac' },{ 'p' => 'linux', 'v' => 'linux' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Computer Platform Type', 'list' => 'LIST_BASE_COMPUTERPLATFORM_TYPE' },
'amz:prod_cp_dgc_connectivity' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'usb', 'v' => 'usb' },{ 'p' => 'usb1.1', 'v' => 'usb1.1' },{ 'p' => 'usb2.0', 'v' => 'usb2.0' },{ 'p' => 'firewire', 'v' => 'firewire' },{ 'p' => 'firewire2.0', 'v' => 'firewire2.0' },{ 'p' => 'serial', 'v' => 'serial' },{ 'p' => 'parallel', 'v' => 'parallel' },{ 'p' => 'ieee1394', 'v' => 'ieee1394' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Connectivity', 'list' => 'LIST_CAMERA_DIGITALCAMERA_CONNECTIVITY' },
'amz:prod_cp_dgc_continuousshooting' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Continuous Shooting', 'type' => 'textbox' },
'amz:prod_cp_dgc_digitalstillcapability' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Digital Still Capability', 'type' => 'checkbox' },
'amz:prod_cp_dgc_digitalstillresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Digital Still Resolution', 'type' => 'textbox' },
'amz:prod_cp_dgc_digitalzoom' => { 'src' => 'amz.camera.digitalcamera.json', 'amz-units' => 'x', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Digital Zoom' },
'amz:prod_cp_dgc_externalmemoryincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'External Memory Included', 'type' => 'checkbox' },
'amz:prod_cp_dgc_externalmemorysize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'External Memory Size', 'type' => 'textbox' },
'amz:prod_cp_dgc_externalmemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'compact-flash', 'v' => 'compact-flash' },{ 'p' => 'smart-media', 'v' => 'smart-media' },{ 'p' => 'secure-digital', 'v' => 'secure-digital' },{ 'p' => 'mmc', 'v' => 'mmc' },{ 'p' => 'xd-picture-card', 'v' => 'xd-picture-card' },{ 'p' => 'memory-stick', 'v' => 'memory-stick' },{ 'p' => 'micro-drive', 'v' => 'micro-drive' },{ 'p' => 'cd-r', 'v' => 'cd-r' },{ 'p' => 'cd-rw', 'v' => 'cd-rw' },{ 'p' => 'dvd-r', 'v' => 'dvd-r' },{ 'p' => 'dvd-rw', 'v' => 'dvd-rw' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera External Memory Type', 'list' => 'LIST_CAMERA_DIGITALCAMERA_EXTERNALMEMORYTYPE' },
'amz:prod_cp_dgc_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'lcd-screen', 'v' => 'lcd-screen' },{ 'p' => 'mpeg-movie-mode', 'v' => 'mpeg-movie-mode' },{ 'p' => 'interchangeable-lens', 'v' => 'interchangeable-lens' },{ 'p' => 'image-stabilization', 'v' => 'image-stabilization' },{ 'p' => 'waterproof', 'v' => 'waterproof' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Features', 'list' => 'LIST_CAMERA_DIGITALCAMERA_FEATURES' },
'amz:prod_cp_dgc_firewireoutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Firewire Output', 'type' => 'checkbox' },
'amz:prod_cp_dgc_flyingeraseheads' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Flying Erase Heads', 'type' => 'checkbox' },
'amz:prod_cp_dgc_focustype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'automatic', 'v' => 'automatic' },{ 'p' => 'manual', 'v' => 'manual' },{ 'p' => 'manual-and-auto', 'v' => 'manual-and-auto' },{ 'p' => 'focus-free', 'v' => 'focus-free' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Focus Type', 'list' => 'LIST_CAMERA_DIGITALCAMERA_FOCUSTYPE' },
'amz:prod_cp_dgc_headphonejack' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Headphone Jack', 'type' => 'checkbox' },
'amz:prod_cp_dgc_hotshoe' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Hot Shoe', 'type' => 'checkbox' },
'amz:prod_cp_dgc_imagestabilization' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Image Stabilization', 'type' => 'checkbox' },
'amz:prod_cp_dgc_infraredcapability' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Infrared Capability', 'type' => 'checkbox' },
'amz:prod_cp_dgc_internalmemorysize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Internal Memory Size', 'type' => 'textbox' },
'amz:prod_cp_dgc_internalmemorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'compact-flash', 'v' => 'compact-flash' },{ 'p' => 'compact-flash-ii', 'v' => 'compact-flash-ii' },{ 'p' => 'pcmcia', 'v' => 'pcmcia' },{ 'p' => 'pcmcia-ii', 'v' => 'pcmcia-ii' },{ 'p' => 'pcmcia-iii', 'v' => 'pcmcia-iii' },{ 'p' => 'smartmedia', 'v' => 'smartmedia' },{ 'p' => 'memory-sticks', 'v' => 'memory-sticks' },{ 'p' => 'sd-multi-media', 'v' => 'sd-multi-media' },{ 'p' => 'xd-picture-card', 'v' => 'xd-picture-card' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Internal Memory Type', 'list' => 'LIST_CAMERA_DIGITALCAMERA_INTERNALMEMORYTYPE' },
'amz:prod_cp_dgc_isoequivalency' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'I S O Equivalency', 'type' => 'textbox' },
'amz:prod_cp_dgc_lcdscreensize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'LCDScreenSize', 'type' => 'number' },
'amz:prod_cp_dgc_lcdswivel' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'L C D Swivel', 'type' => 'checkbox' },
'amz:prod_cp_dgc_lensthread' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'LensThread', 'type' => 'number' },
'amz:prod_cp_dgc_macrofocus' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'MacroFocus', 'type' => 'number' },
'amz:prod_cp_dgc_manualexposuremode' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Manual Exposure Mode', 'type' => 'checkbox' },
'amz:prod_cp_dgc_maxaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Max Aperture', 'type' => 'textbox' },
'amz:prod_cp_dgc_maximageresolution' => { 'src' => 'amz.camera.digitalcamera.json', 'amz-units' => 'pixels', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Max Image Resolution' },
'amz:prod_cp_dgc_maxmovielength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Max Movie Length', 'type' => 'textbox' },
'amz:prod_cp_dgc_maxshutterspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Max Shutter Speed', 'type' => 'textbox' },
'amz:prod_cp_dgc_megapixels' => { 'src' => 'amz.camera.digitalcamera.json', 'amz-units' => 'pixels', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Megapixels' },
'amz:prod_cp_dgc_minaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Min Aperture', 'type' => 'textbox' },
'amz:prod_cp_dgc_minshutterspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Min Shutter Speed', 'type' => 'textbox' },
'amz:prod_cp_dgc_moviemode' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Movie Mode', 'type' => 'checkbox' },
'amz:prod_cp_dgc_opticalzoom' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Optical Zoom', 'type' => 'textbox' },
'amz:prod_cp_dgc_rechargeablebincld' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Rechargeable Battery Included', 'type' => 'checkbox' },
'amz:prod_cp_dgc_remoteincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Remote Included', 'type' => 'checkbox' },
'amz:prod_cp_dgc_s-videooutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'S - Video Output', 'type' => 'checkbox' },
'amz:prod_cp_dgc_selftimer' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Self Timer', 'type' => 'textbox' },
'amz:prod_cp_dgc_sensortype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'ccd', 'v' => 'ccd' },{ 'p' => 'super-ccd', 'v' => 'super-ccd' },{ 'p' => 'cmos', 'v' => 'cmos' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Sensor Type', 'list' => 'LIST_CAMERA_DIGITALCAMERA_SENSORTYPE' },
'amz:prod_cp_dgc_softwareincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'Software Included', 'type' => 'textbox' },
'amz:prod_cp_dgc_uncompressedmode' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'tiff', 'v' => 'tiff' },{ 'p' => 'raw', 'v' => 'raw' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Uncompressed Mode', 'list' => 'LIST_CAMERA_DIGITALCAMERA_UNCOMPRESSEDMODE' },
'amz:prod_cp_dgc_usboutput' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'usb1.1', 'v' => 'usb1.1' },{ 'p' => 'usb2.0', 'v' => 'usb2.0' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera U S B Output', 'list' => 'LIST_CAMERA_DIGITALCAMERA_USBOUTPUT' },
'amz:prod_cp_dgc_usbstreaming' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.digitalcamera.json', 'title' => 'U S B Streaming', 'type' => 'checkbox' },
'amz:prod_cp_dgc_viewfinder' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'optical', 'v' => 'optical' },{ 'p' => 'electronic', 'v' => 'electronic' } ], 'src' => 'amz.camera.digitalcamera.json', 'type' => 'select', 'title' => 'Digital Camera Viewfinder', 'list' => 'LIST_CAMERA_DIGITALCAMERA_VIEWFINDER' },
'amz:prod_cp_dkrm_airregulators' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'air-cleaners', 'v' => 'air-cleaners' },{ 'p' => 'fans', 'v' => 'fans' },{ 'p' => 'louvers', 'v' => 'louvers' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Air Regulators', 'list' => 'LIST_CAMERA_DARKROOM_AIRREGULATORS' },
'amz:prod_cp_dkrm_analyzersandexposuremeters' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'analyzers-and-accessories', 'v' => 'analyzers-and-accessories' },{ 'p' => 'darkroom-exposure-meters', 'v' => 'darkroom-exposure-meters' },{ 'p' => 'densitometers-and-accessories', 'v' => 'densitometers-and-accessories' },{ 'p' => 'grey-cards-and-exposure-guides', 'v' => 'grey-cards-and-exposure-guides' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Analyzers And Exposure Meters', 'list' => 'LIST_CAMERA_DARKROOM_ANALYZERSANDEXPOSUREMETERS' },
'amz:prod_cp_dkrm_chemicals' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black-and-white-film-developer', 'v' => 'black-and-white-film-developer' },{ 'p' => 'black-and-white-fixer', 'v' => 'black-and-white-fixer' },{ 'p' => 'black-and-white-paper-developer', 'v' => 'black-and-white-paper-developer' },{ 'p' => 'black-and-white-stop-baths', 'v' => 'black-and-white-stop-baths' },{ 'p' => 'color-negative-film-chemicals', 'v' => 'color-negative-film-chemicals' },{ 'p' => 'color-slide-film-chemicals', 'v' => 'color-slide-film-chemicals' },{ 'p' => 'chemicals-for-prints-from-color-negatives', 'v' => 'chemicals-for-prints-from-color-negatives' },{ 'p' => 'chemicals-for-prints-from-color-slides', 'v' => 'chemicals-for-prints-from-color-slides' },{ 'p' => 'processing-aids', 'v' => 'processing-aids' },{ 'p' => 'retouching-chemicals', 'v' => 'retouching-chemicals' },{ 'p' => 'wash-aids', 'v' => 'wash-aids' },{ 'p' => 'alternative-chemicals', 'v' => 'alternative-chemicals' },{ 'p' => 'other-chemicals', 'v' => 'other-chemicals' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Chemicals', 'list' => 'LIST_CAMERA_DARKROOM_CHEMICALS' },
'amz:prod_cp_dkrm_easels' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'easels-general', 'v' => 'easels-general' },{ 'p' => 'adjustable-easels', 'v' => 'adjustable-easels' },{ 'p' => 'fixed-size-easels', 'v' => 'fixed-size-easels' },{ 'p' => 'borderless-easels', 'v' => 'borderless-easels' },{ 'p' => 'contact-printers', 'v' => 'contact-printers' },{ 'p' => 'other-easels', 'v' => 'other-easels' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Easels', 'list' => 'LIST_CAMERA_DARKROOM_EASELS' },
'amz:prod_cp_dkrm_enlargers' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'enlargers-general', 'v' => 'enlargers-general' },{ 'p' => 'black-and-white-enlargers', 'v' => 'black-and-white-enlargers' },{ 'p' => 'color-enlargers', 'v' => 'color-enlargers' },{ 'p' => 'variable-contrast-enlargers', 'v' => 'variable-contrast-enlargers' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Enlargers', 'list' => 'LIST_CAMERA_DARKROOM_ENLARGERS' },
'amz:prod_cp_dkrm_enlargingheadandaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'enlarging-heads-general', 'v' => 'enlarging-heads-general' },{ 'p' => 'black-and-white-condenser-heads', 'v' => 'black-and-white-condenser-heads' },{ 'p' => 'color-dichronic-heads', 'v' => 'color-dichronic-heads' },{ 'p' => 'variable-contrast-diffusion-heads', 'v' => 'variable-contrast-diffusion-heads' },{ 'p' => 'cold-light-heads', 'v' => 'cold-light-heads' },{ 'p' => 'enlarging-head-accessories', 'v' => 'enlarging-head-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Enlarging Head And Accessories', 'list' => 'LIST_CAMERA_DARKROOM_ENLARGINGHEADANDACCESSORIES' },
'amz:prod_cp_dkrm_filmprocessingsupplies' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'film-dryers', 'v' => 'film-dryers' },{ 'p' => 'film-reels', 'v' => 'film-reels' },{ 'p' => 'tanks', 'v' => 'tanks' },{ 'p' => 'film-washers', 'v' => 'film-washers' },{ 'p' => 'developing-racks', 'v' => 'developing-racks' },{ 'p' => 'film-hangers', 'v' => 'film-hangers' },{ 'p' => 'film-squeegees', 'v' => 'film-squeegees' },{ 'p' => 'film-cleaning-brushes-and-cloths', 'v' => 'film-cleaning-brushes-and-cloths' },{ 'p' => 'film-cleaning-solutions', 'v' => 'film-cleaning-solutions' },{ 'p' => 'other-film-processing-accessories', 'v' => 'other-film-processing-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Film Processing Supplies', 'list' => 'LIST_CAMERA_DARKROOM_FILMPROCESSINGSUPPLIES' },
'amz:prod_cp_dkrm_generaldevnprocsupplies' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'aprons', 'v' => 'aprons' },{ 'p' => 'blotter-books', 'v' => 'blotter-books' },{ 'p' => 'changing-bags', 'v' => 'changing-bags' },{ 'p' => 'control-strips', 'v' => 'control-strips' },{ 'p' => 'darkroom-pens', 'v' => 'darkroom-pens' },{ 'p' => 'darkroom-pencils', 'v' => 'darkroom-pencils' },{ 'p' => 'darkroom-tapes', 'v' => 'darkroom-tapes' },{ 'p' => 'gloves', 'v' => 'gloves' },{ 'p' => 'paper-safes', 'v' => 'paper-safes' },{ 'p' => 'scales', 'v' => 'scales' },{ 'p' => 'storage-bottles-and-tanks', 'v' => 'storage-bottles-and-tanks' },{ 'p' => 'tray-siphons', 'v' => 'tray-siphons' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom General Developing And Processing Supplies', 'list' => 'LIST_CAMERA_DARKROOM_GENERALDEVELOPINGANDPROCESSINGSUPPLIES' },
'amz:prod_cp_dkrm_mixingeqpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'funnels', 'v' => 'funnels' },{ 'p' => 'graduates', 'v' => 'graduates' },{ 'p' => 'stirring-devices', 'v' => 'stirring-devices' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Mixing Equipment', 'list' => 'LIST_CAMERA_DARKROOM_MIXINGEQUIPMENT' },
'amz:prod_cp_dkrm_otherenlargeraccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'enlarger-lamps', 'v' => 'enlarger-lamps' },{ 'p' => 'enlarging-lens-accessories', 'v' => 'enlarging-lens-accessories' },{ 'p' => 'focusing-aids', 'v' => 'focusing-aids' },{ 'p' => 'lens-boards', 'v' => 'lens-boards' },{ 'p' => 'general-negative-carriers', 'v' => 'general-negative-carriers' },{ 'p' => 'below-35mm-negative-carriers', 'v' => 'below-35mm-negative-carriers' },{ 'p' => '35mm-negative-carriers', 'v' => '35mm-negative-carriers' },{ 'p' => 'medium-format-negative-carriers', 'v' => 'medium-format-negative-carriers' },{ 'p' => 'large-format-negative-carriers', 'v' => 'large-format-negative-carriers' },{ 'p' => 'other-format-negative-carriers', 'v' => 'other-format-negative-carriers' },{ 'p' => 'printing-filters', 'v' => 'printing-filters' },{ 'p' => 'timers', 'v' => 'timers' },{ 'p' => 'other-enlarger-accessories', 'v' => 'other-enlarger-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Other Enlarger Accessories', 'list' => 'LIST_CAMERA_DARKROOM_OTHERENLARGERACCESSORIES' },
'amz:prod_cp_dkrm_paperprocessingsupplies' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'print-drums', 'v' => 'print-drums' },{ 'p' => 'print-dryers', 'v' => 'print-dryers' },{ 'p' => 'roller-bases', 'v' => 'roller-bases' },{ 'p' => 'vertical-slot-processors', 'v' => 'vertical-slot-processors' },{ 'p' => 'washers', 'v' => 'washers' },{ 'p' => 'trays-general', 'v' => 'trays-general' },{ 'p' => '5x7-trays', 'v' => '5x7-trays' },{ 'p' => '8x10-trays', 'v' => '8x10-trays' },{ 'p' => '11x14-trays', 'v' => '11x14-trays' },{ 'p' => '12x16-trays', 'v' => '12x16-trays' },{ 'p' => '16x20-trays', 'v' => '16x20-trays' },{ 'p' => '20x24-trays', 'v' => '20x24-trays' },{ 'p' => '30x40-trays', 'v' => '30x40-trays' },{ 'p' => 'other-paper-processing-accessories', 'v' => 'other-paper-processing-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Paper Processing Supplies', 'list' => 'LIST_CAMERA_DARKROOM_PAPERPROCESSINGSUPPLIES' },
'amz:prod_cp_dkrm_safelightsandaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black-and-white-safelights', 'v' => 'black-and-white-safelights' },{ 'p' => 'color-safelights', 'v' => 'color-safelights' },{ 'p' => 'safelight-filters', 'v' => 'safelight-filters' },{ 'p' => 'other-safelight-accessories', 'v' => 'other-safelight-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Safelights And Accessories', 'list' => 'LIST_CAMERA_DARKROOM_SAFELIGHTSANDACCESSORIES' },
'amz:prod_cp_dkrm_sinksandaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'sinks-general', 'v' => 'sinks-general' },{ 'p' => 'plastic-sinks', 'v' => 'plastic-sinks' },{ 'p' => 'fiberglass-sinks', 'v' => 'fiberglass-sinks' },{ 'p' => 'stainless-steel-sinks', 'v' => 'stainless-steel-sinks' },{ 'p' => 'sink-accessories', 'v' => 'sink-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Sinks And Accessories', 'list' => 'LIST_CAMERA_DARKROOM_SINKSANDACCESSORIES' },
'amz:prod_cp_dkrm_tabletopprocessingsupplies' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'film-drums', 'v' => 'film-drums' },{ 'p' => 'paper-drums', 'v' => 'paper-drums' },{ 'p' => 'processors', 'v' => 'processors' },{ 'p' => 'reels', 'v' => 'reels' },{ 'p' => 'wash-dry-modules', 'v' => 'wash-dry-modules' },{ 'p' => 'other-tabletop-processing-accessories', 'v' => 'other-tabletop-processing-accessories' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Tabletop Processing Supplies', 'list' => 'LIST_CAMERA_DARKROOM_TABLETOPPROCESSINGSUPPLIES' },
'amz:prod_cp_dkrm_watercontrolsandfilters' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'flowmeters', 'v' => 'flowmeters' },{ 'p' => 'thermometers', 'v' => 'thermometers' },{ 'p' => 'temperature-regulators', 'v' => 'temperature-regulators' },{ 'p' => 'tempered-water-heaters', 'v' => 'tempered-water-heaters' },{ 'p' => 'water-panels', 'v' => 'water-panels' },{ 'p' => 'water-control-accessories', 'v' => 'water-control-accessories' },{ 'p' => 'water-filters', 'v' => 'water-filters' } ], 'src' => 'amz.camera.darkroom.json', 'type' => 'select', 'title' => 'Darkroom Water Controls And Filters', 'list' => 'LIST_CAMERA_DARKROOM_WATERCONTROLSANDFILTERS' },
'amz:prod_cp_film_asa-iso' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'up-to-99', 'v' => 'up-to-99' },{ 'p' => '100', 'v' => '100' },{ 'p' => '125', 'v' => '125' },{ 'p' => '160', 'v' => '160' },{ 'p' => '200', 'v' => '200' },{ 'p' => '320', 'v' => '320' },{ 'p' => '400', 'v' => '400' },{ 'p' => 'above-401', 'v' => 'above-401' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film A S A - I S O', 'list' => 'LIST_CAMERA_FILM_ASA-ISO' },
'amz:prod_cp_film_exposurecnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '12-exposure', 'v' => '12-exposure' },{ 'p' => '24-exposure', 'v' => '24-exposure' },{ 'p' => '36-exposure', 'v' => '36-exposure' },{ 'p' => 'other-exposure-count', 'v' => 'other-exposure-count' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film Exposure Count', 'list' => 'LIST_CAMERA_FILM_EXPOSURECOUNT' },
'amz:prod_cp_film_filmcolor' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black-and-white', 'v' => 'black-and-white' },{ 'p' => 'color', 'v' => 'color' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film Film Color', 'list' => 'LIST_CAMERA_FILM_FILMCOLOR' },
'amz:prod_cp_film_filmtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'print', 'v' => 'print' },{ 'p' => 'slide', 'v' => 'slide' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film Film Type', 'list' => 'LIST_CAMERA_FILM_FILMTYPE' },
'amz:prod_cp_film_format' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '35mm', 'v' => '35mm' },{ 'p' => '70mm', 'v' => '70mm' },{ 'p' => '110', 'v' => '110' },{ 'p' => '120', 'v' => '120' },{ 'p' => '220', 'v' => '220' },{ 'p' => '2x3', 'v' => '2x3' },{ 'p' => '4x5', 'v' => '4x5' },{ 'p' => '5x7', 'v' => '5x7' },{ 'p' => '8x10', 'v' => '8x10' },{ 'p' => '11x14', 'v' => '11x14' },{ 'p' => 'aps', 'v' => 'aps' },{ 'p' => 'micro', 'v' => 'micro' },{ 'p' => 'instant', 'v' => 'instant' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film Format', 'list' => 'LIST_CAMERA_FILM_FORMAT' },
'amz:prod_cp_film_lightingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'daylight', 'v' => 'daylight' },{ 'p' => 'infrared', 'v' => 'infrared' },{ 'p' => 'tungsten', 'v' => 'tungsten' } ], 'src' => 'amz.camera.film.json', 'type' => 'select', 'title' => 'Film Lighting Type', 'list' => 'LIST_CAMERA_FILM_LIGHTINGTYPE' },
'amz:prod_cp_filmcamera_autofilmadvance' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Auto Film Advance', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_autofilmload' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Auto Film Load', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_autorewind' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Auto Rewind', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_batterytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Battery Type', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_bincld' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Battery Included', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_cameratype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'point-and-shoot', 'v' => 'point-and-shoot' },{ 'p' => 'slr', 'v' => 'slr' },{ 'p' => 'instant', 'v' => 'instant' },{ 'p' => 'single-use', 'v' => 'single-use' },{ 'p' => 'large-format', 'v' => 'large-format' },{ 'p' => 'medium-format', 'v' => 'medium-format' },{ 'p' => 'rangefinder', 'v' => 'rangefinder' },{ 'p' => 'field', 'v' => 'field' },{ 'p' => 'monorail', 'v' => 'monorail' },{ 'p' => 'kids', 'v' => 'kids' },{ 'p' => '3-d', 'v' => '3-d' },{ 'p' => 'micro', 'v' => 'micro' },{ 'p' => 'panorama', 'v' => 'panorama' },{ 'p' => 'passport-and-id', 'v' => 'passport-and-id' },{ 'p' => 'underwater', 'v' => 'underwater' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Camera Type', 'list' => 'LIST_CAMERA_FILMCAMERA_CAMERATYPE' },
'amz:prod_cp_filmcamera_continuousshooting' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Continuous Shooting', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_dateimprint' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Date Imprint', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_diopteradjustment' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Diopter Adjustment', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_exposurecontrol' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'manual', 'v' => 'manual' },{ 'p' => 'automatic', 'v' => 'automatic' },{ 'p' => 'manual-and-automatic', 'v' => 'manual-and-automatic' },{ 'p' => 'aperture-priority', 'v' => 'aperture-priority' },{ 'p' => 'shutter-speed-priority', 'v' => 'shutter-speed-priority' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Exposure Control', 'list' => 'LIST_CAMERA_FILMCAMERA_EXPOSURECONTROL' },
'amz:prod_cp_filmcamera_filmformat' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'aps', 'v' => 'aps' },{ 'p' => '16mm', 'v' => '16mm' },{ 'p' => '35mm', 'v' => '35mm' },{ 'p' => '110', 'v' => '110' },{ 'p' => '120', 'v' => '120' },{ 'p' => '2x3', 'v' => '2x3' },{ 'p' => '4x5', 'v' => '4x5' },{ 'p' => '5x7', 'v' => '5x7' },{ 'p' => '6x8', 'v' => '6x8' },{ 'p' => '8x10', 'v' => '8x10' },{ 'p' => '8x20', 'v' => '8x20' },{ 'p' => '10x12', 'v' => '10x12' },{ 'p' => '11x14', 'v' => '11x14' },{ 'p' => '12x20', 'v' => '12x20' },{ 'p' => '14x17', 'v' => '14x17' },{ 'p' => '16x20', 'v' => '16x20' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Film Format', 'list' => 'LIST_CAMERA_FILMCAMERA_FILMFORMAT' },
'amz:prod_cp_filmcamera_flashmodes' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Flash Modes', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_flashsynchronization' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Flash Synchronization', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_flashtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'automatic', 'v' => 'automatic' },{ 'p' => 'forced', 'v' => 'forced' },{ 'p' => 'fill', 'v' => 'fill' },{ 'p' => 'none', 'v' => 'none' },{ 'p' => 'flash-override', 'v' => 'flash-override' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Flash Type', 'list' => 'LIST_CAMERA_FILMCAMERA_FLASHTYPE' },
'amz:prod_cp_filmcamera_focustype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'auto-focus', 'v' => 'auto-focus' },{ 'p' => 'manual-focus', 'v' => 'manual-focus' },{ 'p' => 'manual-and-auto-focus', 'v' => 'manual-and-auto-focus' },{ 'p' => 'focus-free', 'v' => 'focus-free' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Focus Type', 'list' => 'LIST_CAMERA_FILMCAMERA_FOCUSTYPE' },
'amz:prod_cp_filmcamera_hotshoe' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Hot Shoe', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_isorange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'I S O Range', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_lcd' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'L C D', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_lenstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'fixed', 'v' => 'fixed' },{ 'p' => 'interchangeable', 'v' => 'interchangeable' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Lens Type', 'list' => 'LIST_CAMERA_FILMCAMERA_LENSTYPE' },
'amz:prod_cp_filmcamera_maxaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Max Aperture', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_maxfocallength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.filmcamera.json', 'title' => 'MaxFocalLength', 'type' => 'number' },
'amz:prod_cp_filmcamera_maxshutterspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Max Shutter Speed', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_meteringmethods' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Metering Methods', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_midrollchange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Midroll Change', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_midrollrewind' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Midroll Rewind', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_minaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Min Aperture', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_minfocallength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.filmcamera.json', 'title' => 'MinFocalLength', 'type' => 'number' },
'amz:prod_cp_filmcamera_minshutterspeed' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Min Shutter Speed', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_opticalzoomrange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'OpticalZoomRange', 'type' => 'number' },
'amz:prod_cp_filmcamera_pkgtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'body-only', 'v' => 'body-only' },{ 'p' => 'multiple-lenses', 'v' => 'multiple-lenses' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Package Type', 'list' => 'LIST_CAMERA_FILMCAMERA_PACKAGETYPE' },
'amz:prod_cp_filmcamera_red-eyereduction' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Red - Eye Reduction', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_remoteincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Remote Included', 'type' => 'checkbox' },
'amz:prod_cp_filmcamera_selftimer' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filmcamera.json', 'title' => 'Self Timer', 'type' => 'textbox' },
'amz:prod_cp_filmcamera_size' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'compact', 'v' => 'compact' },{ 'p' => 'ultra-compact', 'v' => 'ultra-compact' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Size', 'list' => 'LIST_CAMERA_FILMCAMERA_SIZE' },
'amz:prod_cp_filmcamera_viewfinder' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'optical', 'v' => 'optical' },{ 'p' => 'electronic', 'v' => 'electronic' } ], 'src' => 'amz.camera.filmcamera.json', 'type' => 'select', 'title' => 'Film Camera Viewfinder', 'list' => 'LIST_CAMERA_FILMCAMERA_VIEWFINDER' },
'amz:prod_cp_filter_bayonetsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'b-3', 'v' => 'b-3' },{ 'p' => 'b-39', 'v' => 'b-39' },{ 'p' => 'b-50', 'v' => 'b-50' },{ 'p' => 'b-6', 'v' => 'b-6' },{ 'p' => 'b-60', 'v' => 'b-60' },{ 'p' => 'b-70', 'v' => 'b-70' },{ 'p' => 'b-93', 'v' => 'b-93' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Bayonet Size', 'list' => 'LIST_CAMERA_FILTER_BAYONETSIZE' },
'amz:prod_cp_filter_dropinsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '6-inch-wratten', 'v' => '6-inch-wratten' },{ 'p' => 'cokin-a', 'v' => 'cokin-a' },{ 'p' => 'cokin-p', 'v' => 'cokin-p' },{ 'p' => 'lee-type', 'v' => 'lee-type' },{ 'p' => 'pro-optic-a', 'v' => 'pro-optic-a' },{ 'p' => 'pro-optic-p', 'v' => 'pro-optic-p' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Drop In Size', 'list' => 'LIST_CAMERA_FILTER_DROPINSIZE' },
'amz:prod_cp_filter_filtercolor' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'cyan', 'v' => 'cyan' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'magenta', 'v' => 'magenta' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'red-orange', 'v' => 'red-orange' },{ 'p' => 'violet', 'v' => 'violet' },{ 'p' => 'yellow', 'v' => 'yellow' },{ 'p' => 'yellow-green', 'v' => 'yellow-green' },{ 'p' => 'yellow-orange', 'v' => 'yellow-orange' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Filter Color', 'list' => 'LIST_CAMERA_FILTER_FILTERCOLOR' },
'amz:prod_cp_filter_filtertype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'graduated', 'v' => 'graduated' },{ 'p' => 'black-and-white-contrast', 'v' => 'black-and-white-contrast' },{ 'p' => 'close-up', 'v' => 'close-up' },{ 'p' => 'image-softening', 'v' => 'image-softening' },{ 'p' => 'neutral-density', 'v' => 'neutral-density' },{ 'p' => 'general-polarizer', 'v' => 'general-polarizer' },{ 'p' => 'circular-polarizer', 'v' => 'circular-polarizer' },{ 'p' => 'linear-polarizer', 'v' => 'linear-polarizer' },{ 'p' => 'underwater', 'v' => 'underwater' },{ 'p' => 'uv-and-protective', 'v' => 'uv-and-protective' },{ 'p' => 'viewing-filters', 'v' => 'viewing-filters' },{ 'p' => 'lighting-and-compensation', 'v' => 'lighting-and-compensation' },{ 'p' => 'cooling', 'v' => 'cooling' },{ 'p' => 'flourescent', 'v' => 'flourescent' },{ 'p' => 'indoor', 'v' => 'indoor' },{ 'p' => 'outdoor', 'v' => 'outdoor' },{ 'p' => 'warming', 'v' => 'warming' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Filter Type', 'list' => 'LIST_CAMERA_FILTER_FILTERTYPE' },
'amz:prod_cp_filter_forusewith' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'camcorders', 'v' => 'camcorders' },{ 'p' => 'digital-cameras', 'v' => 'digital-cameras' },{ 'p' => 'film-cameras', 'v' => 'film-cameras' },{ 'p' => 'telescopes', 'v' => 'telescopes' },{ 'p' => 'binoculars', 'v' => 'binoculars' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter For Use With', 'list' => 'LIST_CAMERA_FILTER_FORUSEWITH' },
'amz:prod_cp_filter_mounttype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'round', 'v' => 'round' },{ 'p' => 'square', 'v' => 'square' },{ 'p' => 'bayonet', 'v' => 'bayonet' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Mount Type', 'list' => 'LIST_CAMERA_FILTER_MOUNTTYPE' },
'amz:prod_cp_filter_pkgtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'single-filter', 'v' => 'single-filter' },{ 'p' => 'filter-sets', 'v' => 'filter-sets' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Package Type', 'list' => 'LIST_CAMERA_FILTER_PACKAGETYPE' },
'amz:prod_cp_filter_specialeffect' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'center-spot', 'v' => 'center-spot' },{ 'p' => 'cross-screen', 'v' => 'cross-screen' },{ 'p' => 'diffraction', 'v' => 'diffraction' },{ 'p' => 'double-exposure', 'v' => 'double-exposure' },{ 'p' => 'enhancing', 'v' => 'enhancing' },{ 'p' => 'fog', 'v' => 'fog' },{ 'p' => 'hot-mirror', 'v' => 'hot-mirror' },{ 'p' => 'infrared', 'v' => 'infrared' },{ 'p' => 'masks', 'v' => 'masks' },{ 'p' => 'multi-image', 'v' => 'multi-image' },{ 'p' => 'prism', 'v' => 'prism' },{ 'p' => 'sepia', 'v' => 'sepia' },{ 'p' => 'special-contrast', 'v' => 'special-contrast' },{ 'p' => 'speed', 'v' => 'speed' },{ 'p' => 'split-field', 'v' => 'split-field' },{ 'p' => 'star-filters', 'v' => 'star-filters' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Special Effect', 'list' => 'LIST_CAMERA_FILTER_SPECIALEFFECT' },
'amz:prod_cp_filter_specificuses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'travel', 'v' => 'travel' },{ 'p' => 'hiking-and-outdoors', 'v' => 'hiking-and-outdoors' },{ 'p' => 'hunting-and-shooting', 'v' => 'hunting-and-shooting' },{ 'p' => 'sports', 'v' => 'sports' } ], 'src' => 'amz.camera.filter.json', 'type' => 'select', 'title' => 'Filter Specific Uses', 'list' => 'LIST_CAMERA_FILTER_SPECIFICUSES' },
'amz:prod_cp_filter_threadsize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.filter.json', 'title' => 'ThreadSize', 'type' => 'number' },
'amz:prod_cp_flash_dedication' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'dedicated', 'v' => 'dedicated' },{ 'p' => 'non-dedicated', 'v' => 'non-dedicated' } ], 'src' => 'amz.camera.flash.json', 'type' => 'select', 'title' => 'Flash Dedication', 'list' => 'LIST_CAMERA_FLASH_DEDICATION' },
'amz:prod_cp_flash_flashtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'handle-mount', 'v' => 'handle-mount' },{ 'p' => 'macro', 'v' => 'macro' },{ 'p' => 'ring-light', 'v' => 'ring-light' },{ 'p' => 'shoe-mount', 'v' => 'shoe-mount' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.flash.json', 'type' => 'select', 'title' => 'Flash Flash Type', 'list' => 'LIST_CAMERA_FLASH_FLASHTYPE' },
'amz:prod_cp_flash_slaveflashes' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'slave-flashed-general', 'v' => 'slave-flashed-general' },{ 'p' => 'slave-transmitters-and-receivers', 'v' => 'slave-transmitters-and-receivers' },{ 'p' => 'optical-slaves', 'v' => 'optical-slaves' },{ 'p' => 'slave-accessories', 'v' => 'slave-accessories' } ], 'src' => 'amz.camera.flash.json', 'type' => 'select', 'title' => 'Flash Slave Flashes', 'list' => 'LIST_CAMERA_FLASH_SLAVEFLASHES' },
'amz:prod_cp_itemsincluded' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Items Included', 'type' => 'textbox' },
'amz:prod_cp_kwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Keywords', 'type' => 'textlist' },
'amz:prod_cp_lens_cameratype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'camcorder', 'v' => 'camcorder' },{ 'p' => 'digital-camera', 'v' => 'digital-camera' },{ 'p' => '35mm-rangefinder', 'v' => '35mm-rangefinder' },{ 'p' => '35mm-slr', 'v' => '35mm-slr' },{ 'p' => 'aps', 'v' => 'aps' },{ 'p' => 'large-format', 'v' => 'large-format' },{ 'p' => 'medium-format', 'v' => 'medium-format' },{ 'p' => 'underwater', 'v' => 'underwater' } ], 'src' => 'amz.camera.lens.json', 'type' => 'select', 'title' => 'Lens Camera Type', 'list' => 'LIST_CAMERA_LENS_CAMERATYPE' },
'amz:prod_cp_lens_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'all-glass-optical', 'v' => 'all-glass-optical' },{ 'p' => 'apochromatic', 'v' => 'apochromatic' },{ 'p' => 'aspheric', 'v' => 'aspheric' } ], 'src' => 'amz.camera.lens.json', 'type' => 'select', 'title' => 'Lens Features', 'list' => 'LIST_CAMERA_LENS_FEATURES' },
'amz:prod_cp_lens_focustype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'manual-focus', 'v' => 'manual-focus' },{ 'p' => 'auto-focus', 'v' => 'auto-focus' } ], 'src' => 'amz.camera.lens.json', 'type' => 'select', 'title' => 'Lens Focus Type', 'list' => 'LIST_CAMERA_LENS_FOCUSTYPE' },
'amz:prod_cp_lens_lenstype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'wide-angle', 'v' => 'wide-angle' },{ 'p' => 'telephoto', 'v' => 'telephoto' },{ 'p' => 'zoom', 'v' => 'zoom' },{ 'p' => 'macro', 'v' => 'macro' },{ 'p' => 'tilt-shift', 'v' => 'tilt-shift' },{ 'p' => 'fisheye', 'v' => 'fisheye' },{ 'p' => 'teleconverter', 'v' => 'teleconverter' },{ 'p' => 'normal', 'v' => 'normal' } ], 'src' => 'amz.camera.lens.json', 'type' => 'select', 'title' => 'Lens Lens Type', 'list' => 'LIST_CAMERA_LENS_LENSTYPE' },
'amz:prod_cp_lens_maxfocallength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.lens.json', 'title' => 'MaxFocalLength', 'type' => 'number' },
'amz:prod_cp_lens_minfocallength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.lens.json', 'title' => 'MinFocalLength', 'type' => 'number' },
'amz:prod_cp_lensaccessory_accessorytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'c-mounts', 'v' => 'c-mounts' },{ 'p' => 'lens-scope-converters', 'v' => 'lens-scope-converters' },{ 'p' => 'lens-to-camera-adapters', 'v' => 'lens-to-camera-adapters' },{ 'p' => 'remote-lens-controllers', 'v' => 'remote-lens-controllers' },{ 'p' => 'extenders', 'v' => 'extenders' },{ 'p' => 'series-vii-adapters', 'v' => 'series-vii-adapters' },{ 'p' => 't-mounts', 'v' => 't-mounts' },{ 'p' => 'tripod-adapters', 'v' => 'tripod-adapters' },{ 'p' => 'lens-boards', 'v' => 'lens-boards' },{ 'p' => 'bayonets', 'v' => 'bayonets' },{ 'p' => 'lens-hoods', 'v' => 'lens-hoods' },{ 'p' => 'lens-supports', 'v' => 'lens-supports' },{ 'p' => 'rapid-focusing-levers', 'v' => 'rapid-focusing-levers' },{ 'p' => 'shutters', 'v' => 'shutters' },{ 'p' => 'diopters', 'v' => 'diopters' },{ 'p' => 'mirror-scopes', 'v' => 'mirror-scopes' },{ 'p' => 'lens-caps-general', 'v' => 'lens-caps-general' },{ 'p' => 'lens-caps-up-to-48mm', 'v' => 'lens-caps-up-to-48mm' },{ 'p' => 'lens-caps-49mm', 'v' => 'lens-caps-49mm' },{ 'p' => 'lens-caps-52mm', 'v' => 'lens-caps-52mm' },{ 'p' => 'lens-caps-55mm', 'v' => 'lens-caps-55mm' },{ 'p' => 'lens-caps-58mm', 'v' => 'lens-caps-58mm' },{ 'p' => 'lens-caps-62mm', 'v' => 'lens-caps-62mm' },{ 'p' => 'lens-caps-67mm', 'v' => 'lens-caps-67mm' },{ 'p' => 'lens-caps-72mm', 'v' => 'lens-caps-72mm' },{ 'p' => 'lens-caps-77mm', 'v' => 'lens-caps-77mm' },{ 'p' => 'lens-caps-82mm', 'v' => 'lens-caps-82mm' },{ 'p' => 'lens-caps-86mm', 'v' => 'lens-caps-86mm' },{ 'p' => 'lens-caps-95mm', 'v' => 'lens-caps-95mm' },{ 'p' => 'lens-caps-other-sizes', 'v' => 'lens-caps-other-sizes' } ], 'src' => 'amz.camera.lensaccessory.json', 'type' => 'select', 'title' => 'Lens Accessory Accessory Type', 'list' => 'LIST_CAMERA_LENSACCESSORY_ACCESSORYTYPE' },
'amz:prod_cp_lensaccessory_forusewith' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'film-cameras', 'v' => 'film-cameras' },{ 'p' => 'digital-cameras', 'v' => 'digital-cameras' },{ 'p' => 'camcorders', 'v' => 'camcorders' },{ 'p' => 'telescopes', 'v' => 'telescopes' },{ 'p' => 'microscopes', 'v' => 'microscopes' } ], 'src' => 'amz.camera.lensaccessory.json', 'type' => 'select', 'title' => 'Lens Accessory For Use With', 'list' => 'LIST_CAMERA_LENSACCESSORY_FORUSEWITH' },
'amz:prod_cp_lighting_forusewith' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'floodlights', 'v' => 'floodlights' },{ 'p' => 'spotlights', 'v' => 'spotlights' },{ 'p' => 'monolights', 'v' => 'monolights' },{ 'p' => 'flashlights', 'v' => 'flashlights' },{ 'p' => 'ballasts', 'v' => 'ballasts' },{ 'p' => 'cables-and-connectors', 'v' => 'cables-and-connectors' },{ 'p' => 'flash-tubes', 'v' => 'flash-tubes' },{ 'p' => 'head-accessories', 'v' => 'head-accessories' },{ 'p' => 'modeling-lamps', 'v' => 'modeling-lamps' },{ 'p' => 'mounting-hardware', 'v' => 'mounting-hardware' },{ 'p' => 'pack-accessories', 'v' => 'pack-accessories' },{ 'p' => 'special-bulbs', 'v' => 'special-bulbs' },{ 'p' => 'general-power-packs', 'v' => 'general-power-packs' },{ 'p' => '1-head-outfits-power-packs', 'v' => '1-head-outfits-power-packs' },{ 'p' => '2-head-outfits-power-packs', 'v' => '2-head-outfits-power-packs' },{ 'p' => '3-head-outfits-power-packs', 'v' => '3-head-outfits-power-packs' },{ 'p' => '4-head-outfits-power-packs', 'v' => '4-head-outfits-power-packs' },{ 'p' => 'slaves-general', 'v' => 'slaves-general' },{ 'p' => 'flash-activated-slaves', 'v' => 'flash-activated-slaves' },{ 'p' => 'infrared-slaves', 'v' => 'infrared-slaves' },{ 'p' => 'radio-slaves', 'v' => 'radio-slaves' },{ 'p' => 'adapters', 'v' => 'adapters' },{ 'p' => 'barndoors', 'v' => 'barndoors' },{ 'p' => 'cucoloris', 'v' => 'cucoloris' },{ 'p' => 'diffusers', 'v' => 'diffusers' },{ 'p' => 'filters', 'v' => 'filters' },{ 'p' => 'flags', 'v' => 'flags' },{ 'p' => 'gobos', 'v' => 'gobos' },{ 'p' => 'grids', 'v' => 'grids' },{ 'p' => 'inserts', 'v' => 'inserts' },{ 'p' => 'liners', 'v' => 'liners' },{ 'p' => 'louvers', 'v' => 'louvers' },{ 'p' => 'panel-systems', 'v' => 'panel-systems' },{ 'p' => 'reflectors', 'v' => 'reflectors' },{ 'p' => 'snoots', 'v' => 'snoots' },{ 'p' => 'soft-boxes', 'v' => 'soft-boxes' },{ 'p' => 'umbrellas', 'v' => 'umbrellas' } ], 'src' => 'amz.camera.lighting.json', 'type' => 'select', 'title' => 'Lighting For Use With', 'list' => 'LIST_CAMERA_LIGHTING_FORUSEWITH' },
'amz:prod_cp_lighting_lightingsourcetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'flourescent', 'v' => 'flourescent' },{ 'p' => 'hmi', 'v' => 'hmi' },{ 'p' => 'tungsten', 'v' => 'tungsten' } ], 'src' => 'amz.camera.lighting.json', 'type' => 'select', 'title' => 'Lighting Lighting Source Type', 'list' => 'LIST_CAMERA_LIGHTING_LIGHTINGSOURCETYPE' },
'amz:prod_cp_lighting_lightingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'continuous-output', 'v' => 'continuous-output' },{ 'p' => 'strobe', 'v' => 'strobe' } ], 'src' => 'amz.camera.lighting.json', 'type' => 'select', 'title' => 'Lighting Lighting Type', 'list' => 'LIST_CAMERA_LIGHTING_LIGHTINGTYPE' },
'amz:prod_cp_lighting_power' => { 'src' => 'amz.camera.lighting.json', 'amz-units' => 'watts-per-sec', 'ns' => 'product', 'amz-format' => 'Unit', 'type' => 'textbox', 'title' => 'Power' },
'amz:prod_cp_lighting_powertype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'ac', 'v' => 'ac' },{ 'p' => 'dc', 'v' => 'dc' } ], 'src' => 'amz.camera.lighting.json', 'type' => 'select', 'title' => 'Lighting Power Type', 'list' => 'LIST_CAMERA_LIGHTING_POWERTYPE' },
'amz:prod_cp_lighting_specialtyuse' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'underwater', 'v' => 'underwater' } ], 'src' => 'amz.camera.lighting.json', 'type' => 'select', 'title' => 'Lighting Specialty Use', 'list' => 'LIST_CAMERA_LIGHTING_SPECIALTYUSE' },
'amz:prod_cp_lightmeter_cameratype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'film-camera', 'v' => 'film-camera' },{ 'p' => 'digital-camera', 'v' => 'digital-camera' },{ 'p' => 'camcorder', 'v' => 'camcorder' },{ 'p' => 'universal', 'v' => 'universal' } ], 'src' => 'amz.camera.lightmeter.json', 'type' => 'select', 'title' => 'Light Meter Camera Type', 'list' => 'LIST_CAMERA_LIGHTMETER_CAMERATYPE' },
'amz:prod_cp_lightmeter_meterdisplay' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'analog', 'v' => 'analog' },{ 'p' => 'digital', 'v' => 'digital' },{ 'p' => 'led', 'v' => 'led' },{ 'p' => 'match-needle', 'v' => 'match-needle' } ], 'src' => 'amz.camera.lightmeter.json', 'type' => 'select', 'title' => 'Light Meter Meter Display', 'list' => 'LIST_CAMERA_LIGHTMETER_METERDISPLAY' },
'amz:prod_cp_lightmeter_metertype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'ambient', 'v' => 'ambient' },{ 'p' => 'flash', 'v' => 'flash' },{ 'p' => 'ambient-and-flash', 'v' => 'ambient-and-flash' },{ 'p' => 'spot', 'v' => 'spot' },{ 'p' => 'color', 'v' => 'color' } ], 'src' => 'amz.camera.lightmeter.json', 'type' => 'select', 'title' => 'Light Meter Meter Type', 'list' => 'LIST_CAMERA_LIGHTMETER_METERTYPE' },
'amz:prod_cp_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_cp_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_cp_mfrpartnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Mfr Part Number', 'type' => 'textbox' },
'amz:prod_cp_microscope_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'binocular', 'v' => 'binocular' },{ 'p' => 'monocular', 'v' => 'monocular' },{ 'p' => 'trinocular', 'v' => 'trinocular' },{ 'p' => 'fixed-optics', 'v' => 'fixed-optics' },{ 'p' => 'zoom-magnification', 'v' => 'zoom-magnification' } ], 'src' => 'amz.camera.microscope.json', 'type' => 'select', 'title' => 'Microscope Features', 'list' => 'LIST_CAMERA_MICROSCOPE_FEATURES' },
'amz:prod_cp_microscope_microscopetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'digital-and-film-systems', 'v' => 'digital-and-film-systems' },{ 'p' => 'educational-and-hobby', 'v' => 'educational-and-hobby' },{ 'p' => 'laboratory', 'v' => 'laboratory' },{ 'p' => 'stereo', 'v' => 'stereo' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.microscope.json', 'type' => 'select', 'title' => 'Microscope Microscope Type', 'list' => 'LIST_CAMERA_MICROSCOPE_MICROSCOPETYPE' },
'amz:prod_cp_mnfg' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Manufacturer', 'type' => 'textbox' },
'amz:prod_cp_oa_bagcaseaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'liners', 'v' => 'liners' },{ 'p' => 'rain-covers', 'v' => 'rain-covers' },{ 'p' => 'replacement-parts', 'v' => 'replacement-parts' },{ 'p' => 'straps', 'v' => 'straps' },{ 'p' => 'belts', 'v' => 'belts' },{ 'p' => 'harnesses', 'v' => 'harnesses' },{ 'p' => 'inserts', 'v' => 'inserts' },{ 'p' => 'other-bag-and-case-accessories', 'v' => 'other-bag-and-case-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Bag Case Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_BAGCASEACCESSORIES' },
'amz:prod_cp_oa_binocularaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'straps', 'v' => 'straps' },{ 'p' => 'caps', 'v' => 'caps' },{ 'p' => 'other-binocular-accessories', 'v' => 'other-binocular-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Binocular Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_BINOCULARACCESSORIES' },
'amz:prod_cp_oa_camcorderaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'straps', 'v' => 'straps' },{ 'p' => 'remote-controls', 'v' => 'remote-controls' },{ 'p' => 'cables-and-cords', 'v' => 'cables-and-cords' },{ 'p' => 'other-camcorder-accessories', 'v' => 'other-camcorder-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Camcorder Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_CAMCORDERACCESSORIES' },
'amz:prod_cp_oa_cameraaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'close-up-accessories', 'v' => 'close-up-accessories' },{ 'p' => 'viewfinders', 'v' => 'viewfinders' },{ 'p' => 'motor-drives', 'v' => 'motor-drives' },{ 'p' => 'eye-cups', 'v' => 'eye-cups' },{ 'p' => 'winders', 'v' => 'winders' },{ 'p' => 'straps', 'v' => 'straps' },{ 'p' => 'remote-controls', 'v' => 'remote-controls' },{ 'p' => 'cables-and-cords', 'v' => 'cables-and-cords' },{ 'p' => 'other-camera-accessories', 'v' => 'other-camera-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Camera Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_CAMERAACCESSORIES' },
'amz:prod_cp_oa_filmaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mounting-equipment-and-cutters', 'v' => 'mounting-equipment-and-cutters' },{ 'p' => 'slide-mounts', 'v' => 'slide-mounts' },{ 'p' => 'film-mailers', 'v' => 'film-mailers' },{ 'p' => 'film-loaders', 'v' => 'film-loaders' },{ 'p' => 'other-film-accessories', 'v' => 'other-film-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Film Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_FILMACCESSORIES' },
'amz:prod_cp_oa_filteraccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'adapter-rings', 'v' => 'adapter-rings' },{ 'p' => 'filter-caps', 'v' => 'filter-caps' },{ 'p' => 'filter-holders', 'v' => 'filter-holders' },{ 'p' => 'filter-hoods', 'v' => 'filter-hoods' },{ 'p' => 'gel-holder', 'v' => 'gel-holder' },{ 'p' => 'step-down-ring', 'v' => 'step-down-ring' },{ 'p' => 'step-up-ring', 'v' => 'step-up-ring' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Filter Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_FILTERACCESSORIES' },
'amz:prod_cp_oa_flashaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'adapter-rings', 'v' => 'adapter-rings' },{ 'p' => 'battery-packs', 'v' => 'battery-packs' },{ 'p' => 'camera-brackets', 'v' => 'camera-brackets' },{ 'p' => 'flash-bouncers', 'v' => 'flash-bouncers' },{ 'p' => 'flash-diffusers', 'v' => 'flash-diffusers' },{ 'p' => 'flash-filters', 'v' => 'flash-filters' },{ 'p' => 'flash-pouches', 'v' => 'flash-pouches' },{ 'p' => 'flash-shoe-mounts', 'v' => 'flash-shoe-mounts' },{ 'p' => 'synch-and-pc-cords', 'v' => 'synch-and-pc-cords' },{ 'p' => 'other-flash-accessories', 'v' => 'other-flash-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Flash Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_FLASHACCESSORIES' },
'amz:prod_cp_oa_lightmeteraccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'caps', 'v' => 'caps' },{ 'p' => 'gray-cards', 'v' => 'gray-cards' },{ 'p' => 'probes', 'v' => 'probes' },{ 'p' => 'straps', 'v' => 'straps' },{ 'p' => 'other-light-meter-accessories', 'v' => 'other-light-meter-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Light Meter Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_LIGHTMETERACCESSORIES' },
'amz:prod_cp_oa_microscopeaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'boom-stands', 'v' => 'boom-stands' },{ 'p' => 'bulbs', 'v' => 'bulbs' },{ 'p' => 'camera-adapters-and-mounts', 'v' => 'camera-adapters-and-mounts' },{ 'p' => 'eyepieces', 'v' => 'eyepieces' },{ 'p' => 'inspection-systems', 'v' => 'inspection-systems' },{ 'p' => 'light-stands', 'v' => 'light-stands' },{ 'p' => 'microscope-cases', 'v' => 'microscope-cases' },{ 'p' => 'slides-and-slide-kits', 'v' => 'slides-and-slide-kits' },{ 'p' => 'other-microscope-accessories', 'v' => 'other-microscope-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Microscope Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_MICROSCOPEACCESSORIES' },
'amz:prod_cp_oa_specificuses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'travel', 'v' => 'travel' },{ 'p' => 'hiking-and-outdoors', 'v' => 'hiking-and-outdoors' },{ 'p' => 'hunting-and-shooting', 'v' => 'hunting-and-shooting' },{ 'p' => 'sports', 'v' => 'sports' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Specific Uses', 'list' => 'LIST_CAMERA_OTHERACCESSORY_SPECIFICUSES' },
'amz:prod_cp_oa_telescopeaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'barlow-lenses', 'v' => 'barlow-lenses' },{ 'p' => 'collimators', 'v' => 'collimators' },{ 'p' => 'remote-controls', 'v' => 'remote-controls' },{ 'p' => 'electronic-drives', 'v' => 'electronic-drives' },{ 'p' => 'photo-adapters', 'v' => 'photo-adapters' },{ 'p' => 'finderscopes', 'v' => 'finderscopes' },{ 'p' => 'diagonal-mirrors', 'v' => 'diagonal-mirrors' },{ 'p' => 'erecting-prisms', 'v' => 'erecting-prisms' },{ 'p' => 'motor-drives', 'v' => 'motor-drives' },{ 'p' => 'illuminators', 'v' => 'illuminators' },{ 'p' => 'guiders', 'v' => 'guiders' },{ 'p' => 'binocular-viewers', 'v' => 'binocular-viewers' },{ 'p' => 'wedges', 'v' => 'wedges' },{ 'p' => 'mounts', 'v' => 'mounts' },{ 'p' => 'viewfinders', 'v' => 'viewfinders' },{ 'p' => 'sky-maps', 'v' => 'sky-maps' },{ 'p' => 'filters', 'v' => 'filters' },{ 'p' => 'dew-caps', 'v' => 'dew-caps' },{ 'p' => 'other-telescope-accessories', 'v' => 'other-telescope-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Telescope Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_TELESCOPEACCESSORIES' },
'amz:prod_cp_oa_telescopeeyepiece' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'telescope-eyepieces-general', 'v' => 'telescope-eyepieces-general' },{ 'p' => 'orthoscopic', 'v' => 'orthoscopic' },{ 'p' => 'kellner-and-rke', 'v' => 'kellner-and-rke' },{ 'p' => 'erfle', 'v' => 'erfle' },{ 'p' => 'plossl', 'v' => 'plossl' },{ 'p' => 'nagler', 'v' => 'nagler' },{ 'p' => 'zoom', 'v' => 'zoom' },{ 'p' => 'ultra-wide', 'v' => 'ultra-wide' },{ 'p' => 'sma', 'v' => 'sma' },{ 'p' => 'other-eyepieces', 'v' => 'other-eyepieces' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Telescope Eyepiece', 'list' => 'LIST_CAMERA_OTHERACCESSORY_TELESCOPEEYEPIECE' },
'amz:prod_cp_oa_tripodstandaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'monopad-accessories', 'v' => 'monopad-accessories' },{ 'p' => 'camera-stand-accessories', 'v' => 'camera-stand-accessories' },{ 'p' => 'tripod-head-accessories', 'v' => 'tripod-head-accessories' },{ 'p' => 'tripod-leg-accessories', 'v' => 'tripod-leg-accessories' },{ 'p' => 'center-columns', 'v' => 'center-columns' },{ 'p' => 'tripod-adapters', 'v' => 'tripod-adapters' },{ 'p' => 'tripod-straps', 'v' => 'tripod-straps' },{ 'p' => 'camera-mounts-and-clamps', 'v' => 'camera-mounts-and-clamps' },{ 'p' => 'plates', 'v' => 'plates' },{ 'p' => 'other-tripod-accessories', 'v' => 'other-tripod-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Tripod Stand Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_TRIPODSTANDACCESSORIES' },
'amz:prod_cp_oa_underwaterphotographyaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'housings', 'v' => 'housings' },{ 'p' => 'rainguards', 'v' => 'rainguards' },{ 'p' => 'other-underwater-accessories', 'v' => 'other-underwater-accessories' } ], 'src' => 'amz.camera.otheraccessory.json', 'type' => 'select', 'title' => 'Other Accessory Underwater Photography Accessories', 'list' => 'LIST_CAMERA_OTHERACCESSORY_UNDERWATERPHOTOGRAPHYACCESSORIES' },
'amz:prod_cp_photopaper_paperbase' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'polyester-based', 'v' => 'polyester-based' },{ 'p' => 'fiber-based', 'v' => 'fiber-based' },{ 'p' => 'resin-coated', 'v' => 'resin-coated' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.photopaper.json', 'type' => 'select', 'title' => 'Photo Paper Paper Base', 'list' => 'LIST_CAMERA_PHOTOPAPER_PAPERBASE' },
'amz:prod_cp_photopaper_papergrade' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'grade-0', 'v' => 'grade-0' },{ 'p' => 'grade-1', 'v' => 'grade-1' },{ 'p' => 'grade-2', 'v' => 'grade-2' },{ 'p' => 'grade-3', 'v' => 'grade-3' },{ 'p' => 'grade-4', 'v' => 'grade-4' },{ 'p' => 'multigrade', 'v' => 'multigrade' } ], 'src' => 'amz.camera.photopaper.json', 'type' => 'select', 'title' => 'Photo Paper Paper Grade', 'list' => 'LIST_CAMERA_PHOTOPAPER_PAPERGRADE' },
'amz:prod_cp_photopaper_papersize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '10x10', 'v' => '10x10' },{ 'p' => '10x12', 'v' => '10x12' },{ 'p' => '10x20', 'v' => '10x20' },{ 'p' => '11x14', 'v' => '11x14' },{ 'p' => '12x17', 'v' => '12x17' },{ 'p' => '16x20', 'v' => '16x20' },{ 'p' => '20x24', 'v' => '20x24' },{ 'p' => '20x30', 'v' => '20x30' },{ 'p' => '24x30', 'v' => '24x30' },{ 'p' => '3.5x5', 'v' => '3.5x5' },{ 'p' => '30x40', 'v' => '30x40' },{ 'p' => '4x5', 'v' => '4x5' },{ 'p' => '4x6', 'v' => '4x6' },{ 'p' => '5x7', 'v' => '5x7' },{ 'p' => '8.5x11', 'v' => '8.5x11' },{ 'p' => '8x10', 'v' => '8x10' },{ 'p' => 'roll', 'v' => 'roll' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.photopaper.json', 'type' => 'select', 'title' => 'Photo Paper Paper Size', 'list' => 'LIST_CAMERA_PHOTOPAPER_PAPERSIZE' },
'amz:prod_cp_photopaper_papersurface' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'glossy', 'v' => 'glossy' },{ 'p' => 'semi-glossy', 'v' => 'semi-glossy' },{ 'p' => 'matt', 'v' => 'matt' },{ 'p' => 'semi-matt', 'v' => 'semi-matt' },{ 'p' => 'pearl', 'v' => 'pearl' },{ 'p' => 'luster', 'v' => 'luster' },{ 'p' => 'satin', 'v' => 'satin' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.photopaper.json', 'type' => 'select', 'title' => 'Photo Paper Paper Surface', 'list' => 'LIST_CAMERA_PHOTOPAPER_PAPERSURFACE' },
'amz:prod_cp_photopaper_papertype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black-and-white', 'v' => 'black-and-white' },{ 'p' => 'color-negative', 'v' => 'color-negative' },{ 'p' => 'color-reversal', 'v' => 'color-reversal' },{ 'p' => 'ra-chemistry', 'v' => 'ra-chemistry' },{ 'p' => 'other', 'v' => 'other' } ], 'src' => 'amz.camera.photopaper.json', 'type' => 'select', 'title' => 'Photo Paper Paper Type', 'list' => 'LIST_CAMERA_PHOTOPAPER_PAPERTYPE' },
'amz:prod_cp_platinumkwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.filter.json', 'title' => 'Platinum Keywords', 'type' => 'textlist' },
'amz:prod_cp_platinumkwords_10' => { 'ns' => 'product', 'src' => 'amz.camera.film.json', 'title' => 'Platinum Keywords_10', 'type' => 'textbox' },
'amz:prod_cp_powersupply_batterychemicaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'lead-acid', 'v' => 'lead-acid' },{ 'p' => 'lithium', 'v' => 'lithium' },{ 'p' => 'lithium-ion', 'v' => 'lithium-ion' },{ 'p' => 'nickel-metal-hydride', 'v' => 'nickel-metal-hydride' },{ 'p' => 'nicd', 'v' => 'nicd' },{ 'p' => 'silver-oxide', 'v' => 'silver-oxide' },{ 'p' => 'alkaline', 'v' => 'alkaline' },{ 'p' => 'other-battery-types', 'v' => 'other-battery-types' } ], 'src' => 'amz.camera.powersupply.json', 'type' => 'select', 'title' => 'Power Supply Battery Chemical Type', 'list' => 'LIST_CAMERA_POWERSUPPLY_BATTERYCHEMICALTYPE' },
'amz:prod_cp_powersupply_camerapowersupplytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'batteries-general', 'v' => 'batteries-general' },{ 'p' => 'disposable-batteries', 'v' => 'disposable-batteries' },{ 'p' => 'rechargeable-Batteries', 'v' => 'rechargeable-Batteries' },{ 'p' => 'external-batteries', 'v' => 'external-batteries' },{ 'p' => 'battery-packs-general', 'v' => 'battery-packs-general' },{ 'p' => 'shoulder-battery-packs', 'v' => 'shoulder-battery-packs' },{ 'p' => 'belt-battery-packs', 'v' => 'belt-battery-packs' },{ 'p' => 'dedicated-battery-packs', 'v' => 'dedicated-battery-packs' },{ 'p' => 'other-batteries-and-packs', 'v' => 'other-batteries-and-packs' },{ 'p' => 'adapters-general', 'v' => 'adapters-general' },{ 'p' => 'ac-adapters', 'v' => 'ac-adapters' },{ 'p' => 'dc-adapters', 'v' => 'dc-adapters' },{ 'p' => 'battery-chargers', 'v' => 'battery-chargers' },{ 'p' => 'ac-power-supply', 'v' => 'ac-power-supply' },{ 'p' => 'dc-power-supply', 'v' => 'dc-power-supply' },{ 'p' => 'other-power-supplies', 'v' => 'other-power-supplies' } ], 'src' => 'amz.camera.powersupply.json', 'type' => 'select', 'title' => 'Power Supply Camera Power Supply Type', 'list' => 'LIST_CAMERA_POWERSUPPLY_CAMERAPOWERSUPPLYTYPE' },
'amz:prod_cp_powersupply_forusewith' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'film-cameras', 'v' => 'film-cameras' },{ 'p' => 'digital-cameras', 'v' => 'digital-cameras' },{ 'p' => 'analog-camcorders-general', 'v' => 'analog-camcorders-general' },{ 'p' => '8mm-camcorders', 'v' => '8mm-camcorders' },{ 'p' => 'betacam-sp-camcorders', 'v' => 'betacam-sp-camcorders' },{ 'p' => 'hi-8-camcorders', 'v' => 'hi-8-camcorders' },{ 'p' => 's-vhs-camcorders', 'v' => 's-vhs-camcorders' },{ 'p' => 's-vhs-c-camcorders', 'v' => 's-vhs-c-camcorders' },{ 'p' => 'vhs-camcorders', 'v' => 'vhs-camcorders' },{ 'p' => 'vhs-c-camcorders', 'v' => 'vhs-c-camcorders' },{ 'p' => 'other-analog-formats-camcorders', 'v' => 'other-analog-formats-camcorders' },{ 'p' => 'digital-camcorders-general', 'v' => 'digital-camcorders-general' },{ 'p' => 'digital-betacam-camcorders', 'v' => 'digital-betacam-camcorders' },{ 'p' => 'dv-camcorders', 'v' => 'dv-camcorders' },{ 'p' => 'dvcam-camcorders', 'v' => 'dvcam-camcorders' },{ 'p' => 'dvcpro-camcorders', 'v' => 'dvcpro-camcorders' },{ 'p' => 'minidv-camcorders', 'v' => 'minidv-camcorders' },{ 'p' => 'micromv-camcorders', 'v' => 'micromv-camcorders' },{ 'p' => 'digital8-camcorders', 'v' => 'digital8-camcorders' },{ 'p' => 'dvd-camcorders', 'v' => 'dvd-camcorders' },{ 'p' => 'minidisc-camcorders', 'v' => 'minidisc-camcorders' },{ 'p' => 'other-digital-formats-camcorders', 'v' => 'other-digital-formats-camcorders' },{ 'p' => 'flashes', 'v' => 'flashes' },{ 'p' => 'lighting', 'v' => 'lighting' },{ 'p' => 'surveillence-products', 'v' => 'surveillence-products' },{ 'p' => 'other-products', 'v' => 'other-products' } ], 'src' => 'amz.camera.powersupply.json', 'type' => 'select', 'title' => 'Power Supply For Use With', 'list' => 'LIST_CAMERA_POWERSUPPLY_FORUSEWITH' },
'amz:prod_cp_powersupply_powersupplyaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'battery-holders', 'v' => 'battery-holders' },{ 'p' => 'battery-testers', 'v' => 'battery-testers' },{ 'p' => 'mounting-plates', 'v' => 'mounting-plates' },{ 'p' => 'cables-general', 'v' => 'cables-general' },{ 'p' => 'battery-power-cables', 'v' => 'battery-power-cables' },{ 'p' => 'power-supply-cables', 'v' => 'power-supply-cables' },{ 'p' => 'charger-cables', 'v' => 'charger-cables' },{ 'p' => 'adapter-cables', 'v' => 'adapter-cables' },{ 'p' => 'other-cables', 'v' => 'other-cables' },{ 'p' => 'cigarette-connectors', 'v' => 'cigarette-connectors' },{ 'p' => 'xlr-connectors', 'v' => 'xlr-connectors' },{ 'p' => 'dc-couplers', 'v' => 'dc-couplers' } ], 'src' => 'amz.camera.powersupply.json', 'type' => 'select', 'title' => 'Power Supply Power Supply Accessories', 'list' => 'LIST_CAMERA_POWERSUPPLY_POWERSUPPLYACCESSORIES' },
'amz:prod_cp_projection_audiovisualproductaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'dissolve-and-control-units', 'v' => 'dissolve-and-control-units' },{ 'p' => 'lamps', 'v' => 'lamps' },{ 'p' => 'stands', 'v' => 'stands' },{ 'p' => 'mounting-equipment', 'v' => 'mounting-equipment' },{ 'p' => 'other-accessories', 'v' => 'other-accessories' },{ 'p' => 'projector-trays-general', 'v' => 'projector-trays-general' },{ 'p' => '35mm-slide-projector-trays', 'v' => '35mm-slide-projector-trays' },{ 'p' => 'medium-format-slide-projector-trays', 'v' => 'medium-format-slide-projector-trays' } ], 'src' => 'amz.camera.projection.json', 'type' => 'select', 'title' => 'Projection Audio Visual Product Accessories', 'list' => 'LIST_CAMERA_PROJECTION_AUDIOVISUALPRODUCTACCESSORIES' },
'amz:prod_cp_projection_loupemagnification' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'up-to-4x', 'v' => 'up-to-4x' },{ 'p' => '5x-9x', 'v' => '5x-9x' },{ 'p' => '10x-15x', 'v' => '10x-15x' },{ 'p' => 'above-15x', 'v' => 'above-15x' },{ 'p' => 'zoom', 'v' => 'zoom' } ], 'src' => 'amz.camera.projection.json', 'type' => 'select', 'title' => 'Projection Loupe Magnification', 'list' => 'LIST_CAMERA_PROJECTION_LOUPEMAGNIFICATION' },
'amz:prod_cp_projection_projectionscreens' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'fast-fold-screens', 'v' => 'fast-fold-screens' },{ 'p' => 'free-standing-floor-screens', 'v' => 'free-standing-floor-screens' },{ 'p' => 'rear-projection-screens', 'v' => 'rear-projection-screens' },{ 'p' => 'tabletop-screens', 'v' => 'tabletop-screens' },{ 'p' => 'tripod-mounted-screens', 'v' => 'tripod-mounted-screens' },{ 'p' => 'wall-and-ceiling-electric-screens', 'v' => 'wall-and-ceiling-electric-screens' },{ 'p' => 'wall-and-ceiling-screens', 'v' => 'wall-and-ceiling-screens' },{ 'p' => 'other-projection-screens', 'v' => 'other-projection-screens' } ], 'src' => 'amz.camera.projection.json', 'type' => 'select', 'title' => 'Projection Projection Screens', 'list' => 'LIST_CAMERA_PROJECTION_PROJECTIONSCREENS' },
'amz:prod_cp_projection_projectiontype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'slide-projectors', 'v' => 'slide-projectors' },{ 'p' => 'video-projectors', 'v' => 'video-projectors' },{ 'p' => 'large-format-projectors', 'v' => 'large-format-projectors' },{ 'p' => 'medium-format-projectors', 'v' => 'medium-format-projectors' },{ 'p' => 'multimedia-projectors', 'v' => 'multimedia-projectors' },{ 'p' => 'opaque-projectors', 'v' => 'opaque-projectors' },{ 'p' => 'lightboxes', 'v' => 'lightboxes' },{ 'p' => 'viewers', 'v' => 'viewers' },{ 'p' => 'loupes', 'v' => 'loupes' } ], 'src' => 'amz.camera.projection.json', 'type' => 'select', 'title' => 'Projection Projection Type', 'list' => 'LIST_CAMERA_PROJECTION_PROJECTIONTYPE' },
'amz:prod_cp_projection_projectorlenses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '35mm', 'v' => '35mm' },{ 'p' => 'large-format', 'v' => 'large-format' },{ 'p' => 'medium-format', 'v' => 'medium-format' },{ 'p' => 'normal', 'v' => 'normal' },{ 'p' => 'telephoto', 'v' => 'telephoto' },{ 'p' => 'wide-angle', 'v' => 'wide-angle' },{ 'p' => 'zoom', 'v' => 'zoom' },{ 'p' => 'other-projector-lenses', 'v' => 'other-projector-lenses' } ], 'src' => 'amz.camera.projection.json', 'type' => 'select', 'title' => 'Projection Projector Lenses', 'list' => 'LIST_CAMERA_PROJECTION_PROJECTORLENSES' },
'amz:prod_cp_ps_photobackgroundaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'posing-props', 'v' => 'posing-props' },{ 'p' => 'shooting-tables', 'v' => 'shooting-tables' },{ 'p' => 'shooting-tents', 'v' => 'shooting-tents' },{ 'p' => 'studio-accessories', 'v' => 'studio-accessories' },{ 'p' => 'support-equipment', 'v' => 'support-equipment' },{ 'p' => 'other-background-accessories', 'v' => 'other-background-accessories' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Photo Background Accessories', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_PHOTOBACKGROUNDACCESSORIES' },
'amz:prod_cp_ps_photobackgroundfabrics' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'canvas', 'v' => 'canvas' },{ 'p' => 'muslins', 'v' => 'muslins' },{ 'p' => 'seamless-paper', 'v' => 'seamless-paper' },{ 'p' => 'velour', 'v' => 'velour' },{ 'p' => 'other-background-fabrics', 'v' => 'other-background-fabrics' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Photo Background Fabrics', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_PHOTOBACKGROUNDFABRICS' },
'amz:prod_cp_ps_photobackgrounds' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'ceiling-to-floor', 'v' => 'ceiling-to-floor' },{ 'p' => 'collapsible-discs', 'v' => 'collapsible-discs' },{ 'p' => 'free-standing', 'v' => 'free-standing' },{ 'p' => 'graduated', 'v' => 'graduated' },{ 'p' => 'wall-mounted', 'v' => 'wall-mounted' },{ 'p' => 'other-background-styles', 'v' => 'other-background-styles' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Photo Backgrounds', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_PHOTOBACKGROUNDS' },
'amz:prod_cp_ps_photostudioaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mounting-corners', 'v' => 'mounting-corners' },{ 'p' => 'mounting-squares', 'v' => 'mounting-squares' },{ 'p' => 'photographic-tapes', 'v' => 'photographic-tapes' },{ 'p' => 'wire', 'v' => 'wire' },{ 'p' => 'picture-hangers', 'v' => 'picture-hangers' },{ 'p' => 'mats', 'v' => 'mats' },{ 'p' => 'mat-cutters', 'v' => 'mat-cutters' },{ 'p' => 'trimmers', 'v' => 'trimmers' },{ 'p' => 'replacement-blades', 'v' => 'replacement-blades' },{ 'p' => 'other-framing-accessories', 'v' => 'other-framing-accessories' },{ 'p' => 'mounts-general', 'v' => 'mounts-general' },{ 'p' => 'slide-mounts', 'v' => 'slide-mounts' },{ 'p' => 'other-mounts', 'v' => 'other-mounts' },{ 'p' => 'dry-mount-press-accessories', 'v' => 'dry-mount-press-accessories' },{ 'p' => 'mounting-adhesives-general', 'v' => 'mounting-adhesives-general' },{ 'p' => 'dry-mount-tissue', 'v' => 'dry-mount-tissue' },{ 'p' => 'laminating-film', 'v' => 'laminating-film' },{ 'p' => 'print-finishing-lacquers', 'v' => 'print-finishing-lacquers' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Photo Studio Accessories', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_PHOTOSTUDIOACCESSORIES' },
'amz:prod_cp_ps_storageandpresentationmatls' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'hanging-bars', 'v' => 'hanging-bars' },{ 'p' => 'pages-general', 'v' => 'pages-general' },{ 'p' => 'negative-and-unmounted-slides-pages', 'v' => 'negative-and-unmounted-slides-pages' },{ 'p' => 'mounted-slides-pages', 'v' => 'mounted-slides-pages' },{ 'p' => 'prints-pages', 'v' => 'prints-pages' },{ 'p' => 'other-media-pages', 'v' => 'other-media-pages' },{ 'p' => 'sleeves-general', 'v' => 'sleeves-general' },{ 'p' => 'negative-and-unmounted-slides-sleeves', 'v' => 'negative-and-unmounted-slides-sleeves' },{ 'p' => 'mounted-slides-sleeves', 'v' => 'mounted-slides-sleeves' },{ 'p' => 'prints-sleeves', 'v' => 'prints-sleeves' },{ 'p' => 'other-media-sleeves', 'v' => 'other-media-sleeves' },{ 'p' => 'storage-binders-general', 'v' => 'storage-binders-general' },{ 'p' => 'storage-binders-with-rings', 'v' => 'storage-binders-with-rings' },{ 'p' => 'storage-binders-without-rings', 'v' => 'storage-binders-without-rings' },{ 'p' => 'negatives-boxes', 'v' => 'negatives-boxes' },{ 'p' => 'slides-boxes', 'v' => 'slides-boxes' },{ 'p' => 'prints-boxes', 'v' => 'prints-boxes' },{ 'p' => 'other-boxes', 'v' => 'other-boxes' },{ 'p' => 'portfolios', 'v' => 'portfolios' },{ 'p' => 'presentation-boards', 'v' => 'presentation-boards' },{ 'p' => 'glassine-envelopes', 'v' => 'glassine-envelopes' },{ 'p' => 'kraft-envelopes', 'v' => 'kraft-envelopes' },{ 'p' => 'mailers', 'v' => 'mailers' },{ 'p' => 'professional-photo-albums', 'v' => 'professional-photo-albums' },{ 'p' => 'other-professional-albums', 'v' => 'other-professional-albums' },{ 'p' => 'sectional-frames', 'v' => 'sectional-frames' },{ 'p' => 'digital-frames', 'v' => 'digital-frames' },{ 'p' => 'other-professional-frames', 'v' => 'other-professional-frames' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Storage And Presentation Materials', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_STORAGEANDPRESENTATIONMATERIALS' },
'amz:prod_cp_ps_studiosupplies' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'laminating-machines', 'v' => 'laminating-machines' },{ 'p' => 'mounting-press', 'v' => 'mounting-press' },{ 'p' => 'mat-boards-general', 'v' => 'mat-boards-general' },{ 'p' => 'pre-cut-mat-boards', 'v' => 'pre-cut-mat-boards' },{ 'p' => 'heat-activated-boards', 'v' => 'heat-activated-boards' },{ 'p' => 'pressure-sensitive-boards', 'v' => 'pressure-sensitive-boards' },{ 'p' => 'slide-mounters', 'v' => 'slide-mounters' },{ 'p' => 'copystands-general', 'v' => 'copystands-general' },{ 'p' => 'tabletop-copystands', 'v' => 'tabletop-copystands' },{ 'p' => 'instant-copystands', 'v' => 'instant-copystands' },{ 'p' => 'other-copystands', 'v' => 'other-copystands' } ], 'src' => 'amz.camera.photostudio.json', 'type' => 'select', 'title' => 'Photo Studio Studio Supplies', 'list' => 'LIST_CAMERA_PHOTOSTUDIO_STUDIOSUPPLIES' },
'amz:prod_cp_ss_cameraaccs' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mounting-brackets', 'v' => 'mounting-brackets' },{ 'p' => 'power-adapter', 'v' => 'power-adapter' },{ 'p' => 'cable', 'v' => 'cable' },{ 'p' => 'sun-shield', 'v' => 'sun-shield' },{ 'p' => 'camera-controller', 'v' => 'camera-controller' },{ 'p' => 'transmitters', 'v' => 'transmitters' },{ 'p' => 'zoom-lens', 'v' => 'zoom-lens' },{ 'p' => 'pinhole-lens', 'v' => 'pinhole-lens' } ], 'src' => 'amz.camera.surveillancesystem.json', 'type' => 'select', 'title' => 'Surveillance System Camera Accessories', 'list' => 'LIST_CAMERA_SURVEILLANCESYSTEM_CAMERAACCESSORIES' },
'amz:prod_cp_ss_cameratype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'security-cameras', 'v' => 'security-cameras' },{ 'p' => 'dummy-cameras', 'v' => 'dummy-cameras' },{ 'p' => 'bullet-cameras', 'v' => 'bullet-cameras' },{ 'p' => 'web-cameras', 'v' => 'web-cameras' },{ 'p' => 'mirror-image-cameras', 'v' => 'mirror-image-cameras' },{ 'p' => 'dome-cameras', 'v' => 'dome-cameras' },{ 'p' => 'spy-cameras', 'v' => 'spy-cameras' },{ 'p' => 'pinhole-cameras', 'v' => 'pinhole-cameras' },{ 'p' => 'miniature-cameras', 'v' => 'miniature-cameras' },{ 'p' => 'nanny-cameras', 'v' => 'nanny-cameras' },{ 'p' => 'pen-cameras', 'v' => 'pen-cameras' } ], 'src' => 'amz.camera.surveillancesystem.json', 'type' => 'select', 'title' => 'Surveillance System Camera Type', 'list' => 'LIST_CAMERA_SURVEILLANCESYSTEM_CAMERATYPE' },
'amz:prod_cp_ss_features' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'weatherproof', 'v' => 'weatherproof' },{ 'p' => 'motion-detection', 'v' => 'motion-detection' },{ 'p' => 'real-time', 'v' => 'real-time' },{ 'p' => 'indoor', 'v' => 'indoor' },{ 'p' => 'outdoor', 'v' => 'outdoor' },{ 'p' => 'black-and-white', 'v' => 'black-and-white' },{ 'p' => 'color', 'v' => 'color' },{ 'p' => 'night-vision', 'v' => 'night-vision' },{ 'p' => 'day-and-night-camera', 'v' => 'day-and-night-camera' },{ 'p' => 'adjustable-panning', 'v' => 'adjustable-panning' },{ 'p' => 'submersible', 'v' => 'submersible' },{ 'p' => 'wireless', 'v' => 'wireless' },{ 'p' => 'ptz-system', 'v' => 'ptz-system' },{ 'p' => 'digital-spy-camera', 'v' => 'digital-spy-camera' } ], 'src' => 'amz.camera.surveillancesystem.json', 'type' => 'select', 'title' => 'Surveillance System Features', 'list' => 'LIST_CAMERA_SURVEILLANCESYSTEM_FEATURES' },
'amz:prod_cp_ss_surveillancesystemtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'cameras', 'v' => 'cameras' },{ 'p' => 'complete-systems', 'v' => 'complete-systems' },{ 'p' => 'monitors', 'v' => 'monitors' },{ 'p' => 'network-systems', 'v' => 'network-systems' },{ 'p' => 'multiplexer', 'v' => 'multiplexer' } ], 'src' => 'amz.camera.surveillancesystem.json', 'type' => 'select', 'title' => 'Surveillance System Surveillance System Type', 'list' => 'LIST_CAMERA_SURVEILLANCESYSTEM_SURVEILLANCESYSTEMTYPE' },
'amz:prod_cp_tripodstand_forusewith' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'still-cameras', 'v' => 'still-cameras' },{ 'p' => 'camcorders', 'v' => 'camcorders' },{ 'p' => 'still-camera-and-camcorders', 'v' => 'still-camera-and-camcorders' },{ 'p' => 'telescopes', 'v' => 'telescopes' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand For Use With', 'list' => 'LIST_CAMERA_TRIPODSTAND_FORUSEWITH' },
'amz:prod_cp_tripodstand_headtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'geared-heads', 'v' => 'geared-heads' },{ 'p' => 'ball-heads', 'v' => 'ball-heads' },{ 'p' => 'camera-rotator-heads', 'v' => 'camera-rotator-heads' },{ 'p' => 'pan-and-tilt-heads', 'v' => 'pan-and-tilt-heads' },{ 'p' => 'video-heads', 'v' => 'video-heads' },{ 'p' => '3-way-heads', 'v' => '3-way-heads' },{ 'p' => 'panoramic-heads', 'v' => 'panoramic-heads' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand Head Type', 'list' => 'LIST_CAMERA_TRIPODSTAND_HEADTYPE' },
'amz:prod_cp_tripodstand_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'aluminum', 'v' => 'aluminum' },{ 'p' => 'carbon-fiber', 'v' => 'carbon-fiber' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand Material', 'list' => 'LIST_CAMERA_TRIPODSTAND_MATERIAL' },
'amz:prod_cp_tripodstand_pkgtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'head-only', 'v' => 'head-only' },{ 'p' => 'legs-only', 'v' => 'legs-only' },{ 'p' => 'head-and-leg-units', 'v' => 'head-and-leg-units' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand Package Type', 'list' => 'LIST_CAMERA_TRIPODSTAND_PACKAGETYPE' },
'amz:prod_cp_tripodstand_specificuses' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'tabletop', 'v' => 'tabletop' },{ 'p' => 'travel', 'v' => 'travel' },{ 'p' => 'hiking-and-outdoors', 'v' => 'hiking-and-outdoors' },{ 'p' => 'hunting-and-shooting', 'v' => 'hunting-and-shooting' },{ 'p' => 'sports', 'v' => 'sports' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand Specific Uses', 'list' => 'LIST_CAMERA_TRIPODSTAND_SPECIFICUSES' },
'amz:prod_cp_tripodstand_standtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'camera-stands', 'v' => 'camera-stands' },{ 'p' => 'monopods', 'v' => 'monopods' },{ 'p' => 'tripods', 'v' => 'tripods' },{ 'p' => 'car-window-mounts', 'v' => 'car-window-mounts' } ], 'src' => 'amz.camera.tripodstand.json', 'type' => 'select', 'title' => 'Tripod Stand Stand Type', 'list' => 'LIST_CAMERA_TRIPODSTAND_STANDTYPE' },
'amz:prod_cp_ts_batterytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Battery Type', 'type' => 'textbox' },
'amz:prod_cp_ts_bincld' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Battery Included', 'type' => 'checkbox' },
'amz:prod_cp_ts_computerplatform' => { 'ns' => 'product', 'amz-format' => 'ComputerPlatform', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'windows', 'v' => 'windows' },{ 'p' => 'mac', 'v' => 'mac' },{ 'p' => 'linux', 'v' => 'linux' } ], 'src' => 'amz.camera.telescope.json', 'type' => 'select', 'title' => 'Computer Platform Type', 'list' => 'LIST_BASE_COMPUTERPLATFORM_TYPE' },
'amz:prod_cp_ts_daweslimit' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Dawes Limit', 'type' => 'textbox' },
'amz:prod_cp_ts_eyepiecetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Eyepiece Type', 'type' => 'textbox' },
'amz:prod_cp_ts_focallength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.telescope.json', 'title' => 'FocalLength', 'type' => 'number' },
'amz:prod_cp_ts_highestusefulmagnification' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Highest Useful Magnification', 'type' => 'textbox' },
'amz:prod_cp_ts_lowestusefulmagnification' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Lowest Useful Magnification', 'type' => 'textbox' },
'amz:prod_cp_ts_maxaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Max Aperture', 'type' => 'textbox' },
'amz:prod_cp_ts_minaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Min Aperture', 'type' => 'textbox' },
'amz:prod_cp_ts_motorizedcontrols' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Motorized Controls', 'type' => 'textbox' },
'amz:prod_cp_ts_mount' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Mount', 'type' => 'textbox' },
'amz:prod_cp_ts_opticalcoatings' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Optical Coatings', 'type' => 'textbox' },
'amz:prod_cp_ts_opticaltubediameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.telescope.json', 'title' => 'OpticalTubeDiameter', 'type' => 'number' },
'amz:prod_cp_ts_opticaltubelength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.camera.telescope.json', 'title' => 'OpticalTubeLength', 'type' => 'number' },
'amz:prod_cp_ts_photographicresolution' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Photographic Resolution', 'type' => 'textbox' },
'amz:prod_cp_ts_primaryaperture' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'under-80mm', 'v' => 'under-80mm' },{ 'p' => '80mm-90mm', 'v' => '80mm-90mm' },{ 'p' => '100mm-150mm', 'v' => '100mm-150mm' },{ 'p' => '150mm-200mm', 'v' => '150mm-200mm' },{ 'p' => 'over-200mm', 'v' => 'over-200mm' } ], 'src' => 'amz.camera.telescope.json', 'type' => 'select', 'title' => 'Telescope Primary Aperture', 'list' => 'LIST_CAMERA_TELESCOPE_PRIMARYAPERTURE' },
'amz:prod_cp_ts_resolvingpower' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Resolving Power', 'type' => 'textbox' },
'amz:prod_cp_ts_telescopetype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'general', 'v' => 'general' },{ 'p' => 'mirror-lens', 'v' => 'mirror-lens' },{ 'p' => 'schmidt-cassegrain', 'v' => 'schmidt-cassegrain' },{ 'p' => 'maksutov-cassegrain', 'v' => 'maksutov-cassegrain' },{ 'p' => 'reflecting', 'v' => 'reflecting' },{ 'p' => 'newtonian-reflector', 'v' => 'newtonian-reflector' },{ 'p' => 'rich-field-reflector', 'v' => 'rich-field-reflector' },{ 'p' => 'dobsonian-reflector', 'v' => 'dobsonian-reflector' },{ 'p' => 'refracting', 'v' => 'refracting' },{ 'p' => 'achromatic-refractor', 'v' => 'achromatic-refractor' },{ 'p' => 'apochromatic-refractor', 'v' => 'apochromatic-refractor' } ], 'src' => 'amz.camera.telescope.json', 'type' => 'select', 'title' => 'Telescope Telescope Type', 'list' => 'LIST_CAMERA_TELESCOPE_TELESCOPETYPE' },
'amz:prod_cp_ts_viewfinder' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.camera.telescope.json', 'title' => 'Viewfinder', 'type' => 'textbox' },
'amz:prod_grmt_grmtmisc_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.gourmet.gourmetmisc.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_grmt_grmtmisc_ingrdts' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.gourmet.gourmetmisc.json', 'title' => 'Ingredients', 'type' => 'textbox' },
'amz:prod_home_bnb_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.home.bedandbath.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_home_bnb_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.bedandbath.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_home_bnb_nbrofsets' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.bedandbath.json', 'title' => 'NumberOfSets', 'type' => 'number' },
'amz:prod_home_bnb_threadcnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.bedandbath.json', 'title' => 'ThreadCount', 'type' => 'number' },
'amz:prod_home_bnb_wattage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.bedandbath.json', 'title' => 'Wattage', 'type' => 'number' },
'amz:prod_home_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.seedsandplants.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_home_displaydepth' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayDepth', 'type' => 'number' },
'amz:prod_home_displaydiameter' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayDiameter', 'type' => 'number' },
'amz:prod_home_displayheight' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayHeight', 'type' => 'number' },
'amz:prod_home_displaylength' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayLength', 'type' => 'number' },
'amz:prod_home_displaywidth' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayWidth', 'type' => 'number' },
'amz:prod_home_displaywt' => { 'ns' => 'product', 'amz-format' => 'Weight', 'src' => 'amz.home.seedsandplants.json', 'title' => 'DisplayWeight', 'type' => 'number' },
'amz:prod_home_fdecor_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.home.furnitureanddecor.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_home_fdecor_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.furnitureanddecor.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_home_fdecor_nbrofsets' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.furnitureanddecor.json', 'title' => 'NumberOfSets', 'type' => 'number' },
'amz:prod_home_fdecor_threadcnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.furnitureanddecor.json', 'title' => 'ThreadCount', 'type' => 'number' },
'amz:prod_home_fdecor_wattage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.furnitureanddecor.json', 'title' => 'Wattage', 'type' => 'number' },
'amz:prod_home_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.seedsandplants.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_home_kitchen_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.kitchen.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_home_kitchen_nbrofsets' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.kitchen.json', 'title' => 'NumberOfSets', 'type' => 'number' },
'amz:prod_home_kitchen_threadcnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.kitchen.json', 'title' => 'ThreadCount', 'type' => 'number' },
'amz:prod_home_mnfgwarrantydscrpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.seedsandplants.json', 'title' => 'Home Manufacturer Warranty Description', 'type' => 'select', 'list' => 'LIST_HOME_MANUFACTURERWARRANTYDESCRIPTION' },
'amz:prod_home_outdoorliving_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.home.outdoorliving.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_home_outdoorliving_isstainresistant' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.outdoorliving.json', 'title' => 'Is Stain Resistant', 'type' => 'checkbox' },
'amz:prod_home_outdoorliving_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.outdoorliving.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_home_outdoorliving_wattage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.outdoorliving.json', 'title' => 'Wattage', 'type' => 'number' },
'amz:prod_home_snp_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.home.seedsandplants.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_home_snp_moistureneeds' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'little-to-no-watering', 'v' => 'little-to-no-watering' },{ 'p' => 'moderate-watering', 'v' => 'moderate-watering' },{ 'p' => 'regular-watering', 'v' => 'regular-watering' },{ 'p' => 'constant-watering', 'v' => 'constant-watering' } ], 'src' => 'amz.home.seedsandplants.json', 'type' => 'select', 'title' => 'Seeds And Plants Moisture Needs', 'list' => 'LIST_HOME_SEEDSANDPLANTS_MOISTURENEEDS' },
'amz:prod_home_snp_spread' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.seedsandplants.json', 'title' => 'Spread', 'type' => 'number' },
'amz:prod_home_snp_sunlightexposure' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'shade', 'v' => 'shade' },{ 'p' => 'partial-shade', 'v' => 'partial-shade' },{ 'p' => 'partial-sun', 'v' => 'partial-sun' },{ 'p' => 'full-sun', 'v' => 'full-sun' } ], 'src' => 'amz.home.seedsandplants.json', 'type' => 'select', 'title' => 'Seeds And Plants Sunlight Exposure', 'list' => 'LIST_HOME_SEEDSANDPLANTS_SUNLIGHTEXPOSURE' },
'amz:prod_home_snp_sunsetclimatezone' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '1', 'v' => '1' },{ 'p' => '2', 'v' => '2' },{ 'p' => '3', 'v' => '3' },{ 'p' => '4', 'v' => '4' },{ 'p' => '5', 'v' => '5' },{ 'p' => '6', 'v' => '6' },{ 'p' => '7', 'v' => '7' },{ 'p' => '8', 'v' => '8' },{ 'p' => '9', 'v' => '9' },{ 'p' => '10', 'v' => '10' },{ 'p' => '11', 'v' => '11' },{ 'p' => '12', 'v' => '12' },{ 'p' => '13', 'v' => '13' },{ 'p' => '14', 'v' => '14' },{ 'p' => '15', 'v' => '15' },{ 'p' => '16', 'v' => '16' },{ 'p' => '17', 'v' => '17' },{ 'p' => '18', 'v' => '18' },{ 'p' => '19', 'v' => '19' },{ 'p' => '20', 'v' => '20' },{ 'p' => '21', 'v' => '21' },{ 'p' => '22', 'v' => '22' },{ 'p' => '23', 'v' => '23' },{ 'p' => '24', 'v' => '24' } ], 'src' => 'amz.home.seedsandplants.json', 'type' => 'select', 'title' => 'Seeds And Plants Sunset Climate Zone', 'list' => 'LIST_HOME_SEEDSANDPLANTS_SUNSETCLIMATEZONE' },
'amz:prod_home_snp_usdahardinesszone' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => '1', 'v' => '1' },{ 'p' => '2', 'v' => '2' },{ 'p' => '3', 'v' => '3' },{ 'p' => '4', 'v' => '4' },{ 'p' => '5', 'v' => '5' },{ 'p' => '6', 'v' => '6' },{ 'p' => '7', 'v' => '7' },{ 'p' => '8', 'v' => '8' },{ 'p' => '9', 'v' => '9' },{ 'p' => '10', 'v' => '10' },{ 'p' => '11', 'v' => '11' } ], 'src' => 'amz.home.seedsandplants.json', 'type' => 'select', 'title' => 'Seeds And Plants U S D A Hardiness Zone', 'list' => 'LIST_HOME_SEEDSANDPLANTS_USDAHARDINESSZONE' },
'amz:prod_home_volumecapacity' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.home.seedsandplants.json', 'title' => 'Volume Capacity', 'type' => 'textbox' },
'amz:prod_hth_hthmisc_directions' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.health.healthmisc.json', 'title' => 'Directions', 'type' => 'textbox' },
'amz:prod_hth_hthmisc_indications' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.health.healthmisc.json', 'title' => 'Indications', 'type' => 'textbox' },
'amz:prod_hth_hthmisc_ingrdts' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.health.healthmisc.json', 'title' => 'Ingredients', 'type' => 'textlist' },
'amz:prod_hth_hthmisc_isadultproduct' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.health.healthmisc.json', 'title' => 'Is Adult Product', 'type' => 'checkbox' },
'amz:prod_hth_hthmisc_warnings' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.health.healthmisc.json', 'title' => 'Warnings', 'type' => 'textbox' },
'amz:prod_jly_fnearring_backfinding' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Back Finding', 'type' => 'textbox' },
'amz:prod_jly_fnearring_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fnearring_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fnearring_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fnearring_length' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Length', 'type' => 'number' },
'amz:prod_jly_fnearring_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fnearring_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fnearring_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fnearring_nbrofprls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'NumberOfPearls', 'type' => 'number' },
'amz:prod_jly_fnearring_nbrofstones' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'NumberOfStones', 'type' => 'number' },
'amz:prod_jly_fnearring_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fnearring_totalgemwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Total Gem Weight', 'type' => 'textbox' },
'amz:prod_jly_fnearring_totalmetalwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Total Metal Weight', 'type' => 'textbox' },
'amz:prod_jly_fnearring_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineearring.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fnnba_chaintype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Chain Type', 'type' => 'textbox' },
'amz:prod_jly_fnnba_clasptype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Clasp Type', 'type' => 'textbox' },
'amz:prod_jly_fnnba_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fnnba_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fnnba_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fnnba_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fnnba_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fnnba_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fnnba_nbrofprls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'NumberOfPearls', 'type' => 'number' },
'amz:prod_jly_fnnba_nbrofstones' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'NumberOfStones', 'type' => 'number' },
'amz:prod_jly_fnnba_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fnnba_totalgemwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Total Gem Weight', 'type' => 'textbox' },
'amz:prod_jly_fnnba_totalmetalwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Total Metal Weight', 'type' => 'textbox' },
'amz:prod_jly_fnnba_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finenecklacebraceletanklet.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fnother_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fnother_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fnother_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fnother_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fnother_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fnother_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fnother_nbrofprls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'NumberOfPearls', 'type' => 'number' },
'amz:prod_jly_fnother_nbrofstones' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'NumberOfStones', 'type' => 'number' },
'amz:prod_jly_fnother_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fnother_totalgemwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Total Gem Weight', 'type' => 'textbox' },
'amz:prod_jly_fnother_totalmetalwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Total Metal Weight', 'type' => 'textbox' },
'amz:prod_jly_fnother_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fineother.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fnring_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fnring_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fnring_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fnring_length' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Length', 'type' => 'number' },
'amz:prod_jly_fnring_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fnring_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fnring_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fnring_nbrofprls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'NumberOfPearls', 'type' => 'number' },
'amz:prod_jly_fnring_nbrofstones' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'NumberOfStones', 'type' => 'number' },
'amz:prod_jly_fnring_resizable' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Re Sizable', 'type' => 'checkbox' },
'amz:prod_jly_fnring_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fnring_sizinglowerrange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'SizingLowerRange', 'type' => 'number' },
'amz:prod_jly_fnring_sizingupperrange' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'SizingUpperRange', 'type' => 'number' },
'amz:prod_jly_fnring_totalgemwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Total Gem Weight', 'type' => 'textbox' },
'amz:prod_jly_fnring_totalmetalwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Total Metal Weight', 'type' => 'textbox' },
'amz:prod_jly_fnring_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fsnearring_backfinding' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Back Finding', 'type' => 'textbox' },
'amz:prod_jly_fsnearring_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fsnearring_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fsnearring_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fsnearring_length' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Length', 'type' => 'number' },
'amz:prod_jly_fsnearring_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fsnearring_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fsnearring_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fsnearring_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fsnearring_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionearring.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fsnnba_chaintype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Chain Type', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_clasptype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Clasp Type', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fsnnba_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fsnnba_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fsnnba_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_metalype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fsnnba_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionnecklacebraceletanklet.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fsnother_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fsnother_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fsnother_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fsnother_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fsnother_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fsnother_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fsnother_totalmetalwt' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Total Metal Weight', 'type' => 'textbox' },
'amz:prod_jly_fsnother_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionother.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_fsnring_diameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_jly_fsnring_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_fsnring_height' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_jly_fsnring_length' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Length', 'type' => 'number' },
'amz:prod_jly_fsnring_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Material', 'type' => 'textlist' },
'amz:prod_jly_fsnring_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_fsnring_metaltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Metal Type', 'type' => 'textbox' },
'amz:prod_jly_fsnring_settingtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Setting Type', 'type' => 'textbox' },
'amz:prod_jly_fsnring_width' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.fashionring.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_jly_prl_prllustre' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Lustre', 'type' => 'textbox' },
'amz:prod_jly_prl_prlminmcolor' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Minimum Color', 'type' => 'textbox' },
'amz:prod_jly_prl_prlsfcmblms' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Surface Markings And Blemishes', 'type' => 'textbox' },
'amz:prod_jly_prl_prlshape' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Shape', 'type' => 'textbox' },
'amz:prod_jly_prl_prlstringingmethod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Stringing Method', 'type' => 'textbox' },
'amz:prod_jly_prl_prltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Type', 'type' => 'textbox' },
'amz:prod_jly_prl_prluniformity' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.finering.json', 'title' => 'Pearl Uniformity', 'type' => 'textbox' },
'amz:prod_jly_prl_sizeperprl' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.finering.json', 'title' => 'Size Per Pearl', 'type' => 'textbox' },
'amz:prod_jly_watch_bandlength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.watch.json', 'title' => 'Band Length', 'type' => 'textbox' },
'amz:prod_jly_watch_bandmatl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Band Material', 'type' => 'textbox' },
'amz:prod_jly_watch_bandwidth' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.watch.json', 'title' => 'BandWidth', 'type' => 'number' },
'amz:prod_jly_watch_bezelfunction' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Bezel Function', 'type' => 'textbox' },
'amz:prod_jly_watch_bezelmatl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Bezel Material', 'type' => 'textbox' },
'amz:prod_jly_watch_calendartype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Calendar Type', 'type' => 'textbox' },
'amz:prod_jly_watch_casematl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Case Material', 'type' => 'textlist' },
'amz:prod_jly_watch_casesizediameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.watch.json', 'title' => 'CaseSizeDiameter', 'type' => 'number' },
'amz:prod_jly_watch_casesizethickness' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.watch.json', 'title' => 'CaseSizeThickness', 'type' => 'number' },
'amz:prod_jly_watch_clasptype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Clasp Type', 'type' => 'textbox' },
'amz:prod_jly_watch_crystal' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Crystal', 'type' => 'textbox' },
'amz:prod_jly_watch_dialcolor' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Dial Color', 'type' => 'textbox' },
'amz:prod_jly_watch_estateperiod' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Estate Period', 'type' => 'textbox' },
'amz:prod_jly_watch_metalstamp' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Metal Stamp', 'type' => 'textbox' },
'amz:prod_jly_watch_movementtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Movement Type', 'type' => 'textbox' },
'amz:prod_jly_watch_resaletype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Resale Type', 'type' => 'textbox' },
'amz:prod_jly_watch_warrantytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.jewelry.watch.json', 'title' => 'Warranty Type', 'type' => 'textbox' },
'amz:prod_jly_watch_waterresistantdepth' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.jewelry.watch.json', 'title' => 'WaterResistantDepth', 'type' => 'number' },
'amz:prod_misc_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_misc_eventdate' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Event Date', 'type' => 'textbox' },
'amz:prod_misc_kwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Keywords', 'type' => 'textlist' },
'amz:prod_misc_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_misc_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_misc_mfrpartnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Mfr Part Number', 'type' => 'textbox' },
'amz:prod_misc_mnfg' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Manufacturer', 'type' => 'textbox' },
'amz:prod_misc_productcategory' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Antiques', 'v' => 'Antiques' },{ 'p' => 'Art', 'v' => 'Art' },{ 'p' => 'Car_Parts_and_Accessories', 'v' => 'Car_Parts_and_Accessories' },{ 'p' => 'Coins', 'v' => 'Coins' },{ 'p' => 'Collectibles', 'v' => 'Collectibles' },{ 'p' => 'Crafts', 'v' => 'Crafts' },{ 'p' => 'Event_Tickets', 'v' => 'Event_Tickets' },{ 'p' => 'Flowers', 'v' => 'Flowers' },{ 'p' => 'Gifts_and_Occasions', 'v' => 'Gifts_and_Occasions' },{ 'p' => 'Gourmet_Food_and_Wine', 'v' => 'Gourmet_Food_and_Wine' },{ 'p' => 'Hobbies', 'v' => 'Hobbies' },{ 'p' => 'Home_Furniture_and_Decor', 'v' => 'Home_Furniture_and_Decor' },{ 'p' => 'Home_Lighting_and_Lamps', 'v' => 'Home_Lighting_and_Lamps' },{ 'p' => 'Home_Organizers_and_Storage', 'v' => 'Home_Organizers_and_Storage' },{ 'p' => 'Jewelry_and_Gems', 'v' => 'Jewelry_and_Gems' },{ 'p' => 'Luggage', 'v' => 'Luggage' },{ 'p' => 'Major_Home_Appliances', 'v' => 'Major_Home_Appliances' },{ 'p' => 'Medical_Supplies', 'v' => 'Medical_Supplies' },{ 'p' => 'Motorcycles', 'v' => 'Motorcycles' },{ 'p' => 'Musical_Instruments', 'v' => 'Musical_Instruments' },{ 'p' => 'Pet_Supplies', 'v' => 'Pet_Supplies' },{ 'p' => 'Pottery_and_Glass', 'v' => 'Pottery_and_Glass' },{ 'p' => 'Prints_and_Posters', 'v' => 'Prints_and_Posters' },{ 'p' => 'Scientific_Supplies', 'v' => 'Scientific_Supplies' },{ 'p' => 'Sporting_and_Outdoor_Goods', 'v' => 'Sporting_and_Outdoor_Goods' },{ 'p' => 'Sports_Memorabilia', 'v' => 'Sports_Memorabilia' },{ 'p' => 'Stamps', 'v' => 'Stamps' },{ 'p' => 'Teaching_and_School_Supplies', 'v' => 'Teaching_and_School_Supplies' },{ 'p' => 'Watches', 'v' => 'Watches' },{ 'p' => 'Wholesale_and_Industrial', 'v' => 'Wholesale_and_Industrial' },{ 'p' => 'Misc_Other', 'v' => 'Misc_Other' } ], 'src' => 'amz.misc.json', 'type' => 'select', 'title' => 'Product Category', 'list' => 'LIST_MISC_MISCTYPE' },
'amz:prod_misc_productsubcategory' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Decorative_Arts', 'v' => 'Decorative_Arts' },{ 'p' => 'Furniture', 'v' => 'Furniture' },{ 'p' => 'Rugs_Carpets', 'v' => 'Rugs_Carpets' },{ 'p' => 'Silver', 'v' => 'Silver' },{ 'p' => 'Textiles_Linens', 'v' => 'Textiles_Linens' },{ 'p' => 'Drawings', 'v' => 'Drawings' },{ 'p' => 'Mixed_Media', 'v' => 'Mixed_Media' },{ 'p' => 'Paintings', 'v' => 'Paintings' },{ 'p' => 'Sculptures_Carvings', 'v' => 'Sculptures_Carvings' },{ 'p' => 'Car_Accessories', 'v' => 'Car_Accessories' },{ 'p' => 'Car_Parts', 'v' => 'Car_Parts' },{ 'p' => 'Car_Performance', 'v' => 'Car_Performance' },{ 'p' => 'Truck_Accessories', 'v' => 'Truck_Accessories' },{ 'p' => 'Truck_Parts', 'v' => 'Truck_Parts' },{ 'p' => 'Truck_Performance', 'v' => 'Truck_Performance' },{ 'p' => 'Coins_US', 'v' => 'Coins_US' },{ 'p' => 'Coins_World', 'v' => 'Coins_World' },{ 'p' => 'Paper_Money_US', 'v' => 'Paper_Money_US' },{ 'p' => 'Paper_Money_World', 'v' => 'Paper_Money_World' },{ 'p' => 'Scripophily', 'v' => 'Scripophily' },{ 'p' => 'Autographs', 'v' => 'Autographs' },{ 'p' => 'Comics', 'v' => 'Comics' },{ 'p' => 'Holiday_Seasonal', 'v' => 'Holiday_Seasonal' },{ 'p' => 'Militaria', 'v' => 'Militaria' },{ 'p' => 'Trading_Cards', 'v' => 'Trading_Cards' },{ 'p' => 'Corsages', 'v' => 'Corsages' },{ 'p' => 'Exotics', 'v' => 'Exotics' },{ 'p' => 'Flowering_Plants', 'v' => 'Flowering_Plants' },{ 'p' => 'Green_Plants', 'v' => 'Green_Plants' },{ 'p' => 'Mixed_Arrangements', 'v' => 'Mixed_Arrangements' },{ 'p' => 'Single_Flower', 'v' => 'Single_Flower' },{ 'p' => 'Anniversary', 'v' => 'Anniversary' },{ 'p' => 'Birthday', 'v' => 'Birthday' },{ 'p' => 'Holiday', 'v' => 'Holiday' },{ 'p' => 'Wedding', 'v' => 'Wedding' },{ 'p' => 'Cheese', 'v' => 'Cheese' },{ 'p' => 'Wine', 'v' => 'Wine' },{ 'p' => 'Furniture', 'v' => 'Furniture' },{ 'p' => 'Decor', 'v' => 'Decor' },{ 'p' => 'Lighting', 'v' => 'Lighting' },{ 'p' => 'Lamps', 'v' => 'Lamps' },{ 'p' => 'Indoor', 'v' => 'Indoor' },{ 'p' => 'Outdoor', 'v' => 'Outdoor' },{ 'p' => 'Jewelry', 'v' => 'Jewelry' },{ 'p' => 'Gems', 'v' => 'Gems' },{ 'p' => 'Garment_Bags', 'v' => 'Garment_Bags' },{ 'p' => 'Duffle_Bags', 'v' => 'Duffle_Bags' },{ 'p' => 'Kitchen', 'v' => 'Kitchen' },{ 'p' => 'Laundry', 'v' => 'Laundry' },{ 'p' => 'Hospital_Supplies', 'v' => 'Hospital_Supplies' },{ 'p' => 'Home_Health', 'v' => 'Home_Health' },{ 'p' => 'Motorcyles', 'v' => 'Motorcyles' },{ 'p' => 'Motorcycle_Parts', 'v' => 'Motorcycle_Parts' },{ 'p' => 'Motorcycle_Protective_Gear', 'v' => 'Motorcycle_Protective_Gear' },{ 'p' => 'Pet_Care', 'v' => 'Pet_Care' },{ 'p' => 'Pet_Food', 'v' => 'Pet_Food' },{ 'p' => 'Pet_Toys', 'v' => 'Pet_Toys' },{ 'p' => 'Glass', 'v' => 'Glass' },{ 'p' => 'Pottery', 'v' => 'Pottery' },{ 'p' => 'Posters', 'v' => 'Posters' },{ 'p' => 'Prints', 'v' => 'Prints' },{ 'p' => 'Lab_Supplies', 'v' => 'Lab_Supplies' },{ 'p' => 'Sporting_Goods', 'v' => 'Sporting_Goods' },{ 'p' => 'Outdoor_Gear', 'v' => 'Outdoor_Gear' },{ 'p' => 'Autographs', 'v' => 'Autographs' },{ 'p' => 'Trading_Cards', 'v' => 'Trading_Cards' },{ 'p' => 'Stamps_US', 'v' => 'Stamps_US' },{ 'p' => 'Stamps_World', 'v' => 'Stamps_World' },{ 'p' => 'Preschool', 'v' => 'Preschool' },{ 'p' => 'K-12', 'v' => 'K-12' },{ 'p' => 'Special_Needs', 'v' => 'Special_Needs' },{ 'p' => 'Men', 'v' => 'Men' },{ 'p' => 'Women', 'v' => 'Women' },{ 'p' => 'Kids', 'v' => 'Kids' },{ 'p' => 'Agriculture', 'v' => 'Agriculture' },{ 'p' => 'Architecture', 'v' => 'Architecture' },{ 'p' => 'Construction', 'v' => 'Construction' },{ 'p' => 'Marine', 'v' => 'Marine' },{ 'p' => 'Metalworking', 'v' => 'Metalworking' },{ 'p' => 'Other', 'v' => 'Other' } ], 'src' => 'amz.misc.json', 'type' => 'select', 'title' => 'Product Subcategory', 'list' => 'LIST_MISC_SUBTYPE' },
'amz:prod_misc_producttype' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Antiques', 'v' => 'Antiques' },{ 'p' => 'Art', 'v' => 'Art' },{ 'p' => 'Car_Parts_and_Accessories', 'v' => 'Car_Parts_and_Accessories' },{ 'p' => 'Coins', 'v' => 'Coins' },{ 'p' => 'Collectibles', 'v' => 'Collectibles' },{ 'p' => 'Crafts', 'v' => 'Crafts' },{ 'p' => 'Event_Tickets', 'v' => 'Event_Tickets' },{ 'p' => 'Flowers', 'v' => 'Flowers' },{ 'p' => 'Gifts_and_Occasions', 'v' => 'Gifts_and_Occasions' },{ 'p' => 'Gourmet_Food_and_Wine', 'v' => 'Gourmet_Food_and_Wine' },{ 'p' => 'Hobbies', 'v' => 'Hobbies' },{ 'p' => 'Home_Furniture_and_Decor', 'v' => 'Home_Furniture_and_Decor' },{ 'p' => 'Home_Lighting_and_Lamps', 'v' => 'Home_Lighting_and_Lamps' },{ 'p' => 'Home_Organizers_and_Storage', 'v' => 'Home_Organizers_and_Storage' },{ 'p' => 'Jewelry_and_Gems', 'v' => 'Jewelry_and_Gems' },{ 'p' => 'Luggage', 'v' => 'Luggage' },{ 'p' => 'Major_Home_Appliances', 'v' => 'Major_Home_Appliances' },{ 'p' => 'Medical_Supplies', 'v' => 'Medical_Supplies' },{ 'p' => 'Motorcycles', 'v' => 'Motorcycles' },{ 'p' => 'Musical_Instruments', 'v' => 'Musical_Instruments' },{ 'p' => 'Pet_Supplies', 'v' => 'Pet_Supplies' },{ 'p' => 'Pottery_and_Glass', 'v' => 'Pottery_and_Glass' },{ 'p' => 'Prints_and_Posters', 'v' => 'Prints_and_Posters' },{ 'p' => 'Scientific_Supplies', 'v' => 'Scientific_Supplies' },{ 'p' => 'Sporting_and_Outdoor_Goods', 'v' => 'Sporting_and_Outdoor_Goods' },{ 'p' => 'Sports_Memorabilia', 'v' => 'Sports_Memorabilia' },{ 'p' => 'Stamps', 'v' => 'Stamps' },{ 'p' => 'Teaching_and_School_Supplies', 'v' => 'Teaching_and_School_Supplies' },{ 'p' => 'Watch', 'v' => 'Watch' },{ 'p' => 'Wholesale_and_Industrial', 'v' => 'Wholesale_and_Industrial' },{ 'p' => 'Misc_Other', 'v' => 'Misc_Other' } ], 'src' => 'amz.misc.json', 'type' => 'select', 'title' => 'Product Type', 'list' => 'LIST_MISC_MISCTYPE' },
'amz:prod_misc_size' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.misc.json', 'title' => 'Size', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_inmtkey' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Instrument Key', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_bawwinmts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_bawwinmts_proficiencylevel' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'Intermediate', 'v' => 'Intermediate' },{ 'p' => 'Professional', 'v' => 'Professional' },{ 'p' => 'Student', 'v' => 'Student' } ], 'src' => 'amz.musicinst.brassandwoodwindinstruments.json', 'type' => 'select', 'title' => 'Brass And Woodwind Instruments Proficiency Level', 'list' => 'LIST_MUSICINST_BRASSANDWOODWINDINSTRUMENTS_PROFICIENCYLEVEL' },
'amz:prod_mus_gtrs_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_gtrs_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_gtrs_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_gtrs_gtrattribute' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'dreadnought', 'v' => 'dreadnought' },{ 'p' => 'fretless', 'v' => 'fretless' },{ 'p' => 'grand-auditorium', 'v' => 'grand-auditorium' },{ 'p' => 'grand-concert', 'v' => 'grand-concert' },{ 'p' => 'jumbo', 'v' => 'jumbo' },{ 'p' => 'mini', 'v' => 'mini' },{ 'p' => 'nex', 'v' => 'nex' },{ 'p' => 'shallow-body', 'v' => 'shallow-body' },{ 'p' => 'short-scale', 'v' => 'short-scale' },{ 'p' => 'travel', 'v' => 'travel' } ], 'src' => 'amz.musicinst.guitars.json', 'type' => 'select', 'title' => 'Guitars Guitar Attribute', 'list' => 'LIST_MUSICINST_GUITARS_GUITARATTRIBUTE' },
'amz:prod_mus_gtrs_gtrbridgesystem' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'fixed', 'v' => 'fixed' },{ 'p' => 'tremolo', 'v' => 'tremolo' } ], 'src' => 'amz.musicinst.guitars.json', 'type' => 'select', 'title' => 'Guitars Guitar Bridge System', 'list' => 'LIST_MUSICINST_GUITARS_GUITARBRIDGESYSTEM' },
'amz:prod_mus_gtrs_gtrpickupconfiguration' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'humbucker', 'v' => 'humbucker' },{ 'p' => 'magnetic-combination', 'v' => 'magnetic-combination' },{ 'p' => 'magnetic-double-coil', 'v' => 'magnetic-double-coil' },{ 'p' => 'magnetic-single-coil', 'v' => 'magnetic-single-coil' },{ 'p' => 'piezoelectric', 'v' => 'piezoelectric' } ], 'src' => 'amz.musicinst.guitars.json', 'type' => 'select', 'title' => 'Guitars Guitar Pickup Configuration', 'list' => 'LIST_MUSICINST_GUITARS_GUITARPICKUPCONFIGURATION' },
'amz:prod_mus_gtrs_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_gtrs_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_gtrs_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_gtrs_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_gtrs_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_gtrs_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_gtrs_nbrofstrings' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.guitars.json', 'title' => 'NumberOfStrings', 'type' => 'number' },
'amz:prod_mus_inmtpartsacc_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_cablelength' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'CableLength', 'type' => 'number' },
'amz:prod_mus_inmtpartsacc_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_drumstickssize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Drum Sticks Size', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_gtrpickthickness' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'extra-thick', 'v' => 'extra-thick' },{ 'p' => 'medium', 'v' => 'medium' },{ 'p' => 'thick', 'v' => 'thick' },{ 'p' => 'thin', 'v' => 'thin' } ], 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'type' => 'select', 'title' => 'Instrument Parts And Accessories Guitar Pick Thickness', 'list' => 'LIST_MUSICINST_INSTRUMENTPARTSANDACCESSORIES_GUITARPICKTHICKNESS' },
'amz:prod_mus_inmtpartsacc_inmtkey' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Instrument Key', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_inmtpartsacc_mallethardness' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'extra-hard', 'v' => 'extra-hard' },{ 'p' => 'hard', 'v' => 'hard' },{ 'p' => 'medium', 'v' => 'medium' },{ 'p' => 'soft', 'v' => 'soft' } ], 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'type' => 'select', 'title' => 'Instrument Parts And Accessories Mallet Hardness', 'list' => 'LIST_MUSICINST_INSTRUMENTPARTSANDACCESSORIES_MALLETHARDNESS' },
'amz:prod_mus_inmtpartsacc_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_inmtpartsacc_nbrofkeybrdkeys' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'NumberOfKeybrdKeys', 'type' => 'number' },
'amz:prod_mus_inmtpartsacc_percndiameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.musicinst.instrumentpartsandaccessories.json', 'title' => 'Percussion Diameter', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_inmtkey' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Instrument Key', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_keybrdinmts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_keybrdinmts_nbrofkeybrdkeys' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.keyboardinstruments.json', 'title' => 'NumberOfKeybrdKeys', 'type' => 'number' },
'amz:prod_mus_miscwrldinmts_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_miscwrldinmts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_miscwrldinmts_regionoforgn' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.miscworldinstruments.json', 'title' => 'Region Of Origin', 'type' => 'textbox' },
'amz:prod_mus_percninmts_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_percninmts_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_percninmts_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_percninmts_drumsetpieceqty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'DrumSetPieceQty', 'type' => 'number' },
'amz:prod_mus_percninmts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_percninmts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_percninmts_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_percninmts_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_percninmts_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_percninmts_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_percninmts_nbrofkeybrdkeys' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'NumberOfKeybrdKeys', 'type' => 'number' },
'amz:prod_mus_percninmts_percndiameter' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.musicinst.percussioninstruments.json', 'title' => 'Percussion Diameter', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_sndeqpt_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_mixerchannelqty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'MixerChannelQty', 'type' => 'number' },
'amz:prod_mus_sndeqpt_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_sndeqpt_outputwattage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'OutputWattage', 'type' => 'number' },
'amz:prod_mus_sndeqpt_recordertrackcnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'RecorderTrackCount', 'type' => 'number' },
'amz:prod_mus_sndeqpt_speakercnt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'SpeakerCount', 'type' => 'number' },
'amz:prod_mus_sndeqpt_speakersize' => { 'ns' => 'product', 'amz-format' => 'Measurement', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'SpeakerSize', 'type' => 'number' },
'amz:prod_mus_sndeqpt_wrlsmicrophonefqcy' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.soundandrecordingequipment.json', 'title' => 'Wireless Microphone Frequency', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_addlspecs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Additional Specifications', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_ctryprdin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Country Produced In', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_inmtkey' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Instrument Key', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_inmtsize' => { 'ns' => 'product', 'amz-format' => 'Scalar', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Instrument Size', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_mus_strgdinmts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Material Type', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_mdlname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Model Name', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_mdlnbr' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Model Number', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_mdlyear' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Model Year', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_musicalstyle' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'Musical Style', 'type' => 'textbox' },
'amz:prod_mus_strgdinmts_nbrofstrings' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.musicinst.stringedinstruments.json', 'title' => 'NumberOfStrings', 'type' => 'number' },
'amz:prod_ofc_artsupplies_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.office.artsupplies.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_ofc_artsupplies_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.artsupplies.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_ofc_artsupplies_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.artsupplies.json', 'title' => 'Material Type', 'type' => 'textlist' },
'amz:prod_ofc_artsupplies_painttype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.artsupplies.json', 'title' => 'Paint Type', 'type' => 'textlist' },
'amz:prod_ofc_edlsupplies_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.educationalsupplies.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_ofc_ofcproducts_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.officeproducts.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_ofc_ofcproducts_matltype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.office.officeproducts.json', 'title' => 'Material Type', 'type' => 'textlist' },
'amz:prod_petsps_petspsmisc_clrspec' => { 'ns' => 'product', 'amz-format' => 'ColorSpecification', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_petsps_petspsmisc_ingrdts' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'title' => 'Ingredients', 'type' => 'textbox' },
'amz:prod_petsps_petspsmisc_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'default' => '1', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_petsps_petspsmisc_matl' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'title' => 'Material', 'type' => 'textbox' },
'amz:prod_petsps_petspsmisc_size' => { 'ns' => 'product', 'amz-format' => 'Scalar', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'title' => 'Size', 'type' => 'textbox' },
'amz:prod_petsps_petspsmisc_volume' => { 'ns' => 'product', 'amz-format' => 'Weight', 'src' => 'amz.petsupply.petsuppliesmisc.json', 'title' => 'Volume', 'type' => 'textbox' },
'amz:prod_sports_cstmztemplatename' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'Customizable Template Name', 'type' => 'textbox' },
'amz:prod_sports_dpt' => { 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'mens', 'v' => 'mens' },{ 'p' => 'womens', 'v' => 'womens' },{ 'p' => 'boys', 'v' => 'boys' },{ 'p' => 'girls', 'v' => 'girls' },{ 'p' => 'baby', 'v' => 'baby' },{ 'p' => 'youth', 'v' => 'youth' },{ 'p' => 'unisex', 'v' => 'unisex' } ], 'src' => 'amz.sports.json', 'ns' => 'product', 'amz-attr' => 'department', 'amz-format' => 'Text', 'type' => 'select', 'title' => 'Department', 'amz-max-length' => 49 },
'amz:prod_sports_leaguename' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'League Name', 'type' => 'textbox' },
'amz:prod_sports_playername' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'Player Name', 'type' => 'textbox' },
'amz:prod_sports_teamname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'Team Name', 'type' => 'textbox' },
'amz:prod_shoe_cd_framematerialtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.shoes.json', 'title' => 'Frame Material Type', 'type' => 'select' },
'amz:prod_shoe_cd_itemshape' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.shoes.json', 'title' => 'Item Shape', 'type' => 'select' },
'amz:prod_shoe_cd_lenscolormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.shoes.json', 'title' => 'Lens Color Map', 'type' => 'select' },
'amz:prod_shoe_cd_lensmaterialtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.shoes.json', 'title' => 'Lens Material Type', 'type' => 'select' },
'amz:prod_shoe_cd_polarizationtype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.shoes.json', 'title' => 'Polarization Type', 'type' => 'select' },
'amz:prod_sports_iscstmz' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'Is Customizable', 'type' => 'checkbox' },
'amz:prod_sports_packaging' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.sports.json', 'title' => 'Packaging', 'type' => 'textbox' },
'amz:prod_swvg_hhswdls_applnvrsn' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.handheldsoftwaredownloads.json', 'title' => 'Application Version', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_swvg_hhswdls_nbroflicenses' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.handheldsoftwaredownloads.json', 'title' => 'NumberOfLicenses', 'type' => 'number' },
'amz:prod_swvg_hhswdls_os' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.handheldsoftwaredownloads.json', 'title' => 'Operating System', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_hhswdls_systemreqs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.handheldsoftwaredownloads.json', 'title' => 'System Requirements', 'type' => 'textbox' },
'amz:prod_swvg_swg_bundles' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Bundles', 'type' => 'textbox' },
'amz:prod_swvg_swg_esrbdescriptors' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'E S R B Descriptors', 'type' => 'textlist' },
'amz:prod_swvg_swg_esrbrating' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'E S R B Rating', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_swvg_swg_maxnbrofplayers' => { 'ns' => 'product', 'amz-format' => 'Players', 'src' => 'amz.software.softwaregames.json', 'title' => 'MaxNumberOfPlayers', 'type' => 'number' },
'amz:prod_swvg_swg_mediaformat' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Media Format', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_swg_mfgsuggestedagemax' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'MFGSuggestedAgeMax', 'type' => 'number' },
'amz:prod_swvg_swg_mfgsuggestedagemin' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'MFGSuggestedAgeMin', 'type' => 'number' },
'amz:prod_swvg_swg_onlineplay' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Online Play', 'type' => 'checkbox' },
'amz:prod_swvg_swg_os' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Operating System', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_swg_software_platform' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Software Platform', 'type' => 'textbox' },
'amz:prod_swvg_swg_swvggenre' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'title' => 'Software Video Games Genre', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_swpt_dofi' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.handheldsoftwaredownloads.json', 'title' => 'Downloadable File', 'type' => 'textbox' },
'amz:prod_swvg_swpt_systemreqs' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.softwaregames.json', 'default' => 'N/A', 'title' => 'System Requirements', 'type' => 'textbox' },
'amz:prod_swvg_vg_bundles' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogames.json', 'title' => 'Bundles', 'type' => 'textbox' },
'amz:prod_swvg_vg_consolevggenre' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogames.json', 'title' => 'Console Video Games Genre', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_vg_esrbdescriptors' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogames.json', 'title' => 'E S R B Descriptors', 'type' => 'textlist' },
'amz:prod_swvg_vg_esrbrating' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogames.json', 'title' => 'E S R B Rating', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_swvg_vg_hwpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogames.json', 'title' => 'Hardware Platform', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_swvg_vg_maxnbrofplayers' => { 'ns' => 'product', 'amz-format' => 'Players', 'src' => 'amz.software.videogames.json', 'title' => 'MaxNumberOfPlayers', 'type' => 'number' },
'amz:prod_swvg_vgaccs_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogamesaccessories.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_swvg_vgaccs_bundles' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogamesaccessories.json', 'title' => 'Bundles', 'type' => 'textbox' },
'amz:prod_swvg_vgaccs_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogamesaccessories.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_swvg_vgaccs_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.software.videogamesaccessories.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_swvg_vgaccs_hwpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogamesaccessories.json', 'title' => 'Hardware Platform', 'mandatory' => 'Y', 'type' => 'textlist' },
'amz:prod_swvg_vgaccs_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogamesaccessories.json', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_swvg_vghardware_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogameshardware.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_swvg_vghardware_bundles' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogameshardware.json', 'title' => 'Bundles', 'type' => 'textbox' },
'amz:prod_swvg_vghardware_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogameshardware.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_swvg_vghardware_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.software.videogameshardware.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_swvg_vghardware_hwpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogameshardware.json', 'title' => 'Hardware Platform', 'mandatory' => 'Y', 'type' => 'textbox' },
'amz:prod_swvg_vghardware_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.software.videogameshardware.json', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_tools_diameter' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.tools.json', 'title' => 'Diameter', 'type' => 'number' },
'amz:prod_tools_gritrating' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.tools.json', 'title' => 'GritRating', 'type' => 'number' },
'amz:prod_tools_height' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.tools.json', 'title' => 'Height', 'type' => 'number' },
'amz:prod_tools_horsepower' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.tools.json', 'title' => 'Horsepower', 'type' => 'textbox' },
'amz:prod_tools_length' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.tools.json', 'title' => 'Length', 'type' => 'number' },
'amz:prod_tools_nbrofitemsinpkg' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.tools.json', 'title' => 'NumberOfItemsInPackage', 'type' => 'number' },
'amz:prod_tools_powersource' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'battery-powered', 'v' => 'battery-powered' },{ 'p' => 'gas-powered', 'v' => 'gas-powered' },{ 'p' => 'hydraulic-powered', 'v' => 'hydraulic-powered' },{ 'p' => 'air-powered', 'v' => 'air-powered' },{ 'p' => 'corded-electric', 'v' => 'corded-electric' } ], 'src' => 'amz.tools.json', 'type' => 'select', 'title' => 'Tools Power Source', 'list' => 'LIST_TOOLS_POWERSOURCE' },
'amz:prod_tools_voltage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.tools.json', 'title' => 'Voltage', 'type' => 'number' },
'amz:prod_tools_wattage' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.tools.json', 'title' => 'Wattage', 'type' => 'number' },
'amz:prod_tools_width' => { 'ns' => 'product', 'amz-format' => 'Length', 'src' => 'amz.tools.json', 'title' => 'Width', 'type' => 'number' },
'amz:prod_tools_wt' => { 'ns' => 'product', 'amz-format' => 'Weight', 'src' => 'amz.tools.json', 'title' => 'Weight', 'type' => 'number' },
'amz:prod_toysbaby_assemblyinstrts' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Assembly Instructions', 'type' => 'textbox' },
'amz:prod_toysbaby_assemblytime' => { 'ns' => 'product', 'amz-format' => 'Time', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Assembly Time', 'type' => 'textbox' },
'amz:prod_toysbaby_isassemblyrequired' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Is Assembly Required', 'type' => 'checkbox' },
'amz:prod_toysbaby_maxmmerchantagerecd' => { 'ns' => 'product', 'amz-format' => 'Age', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Maximum Merchant Age Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_maxmmnfgagerecd' => { 'ns' => 'product', 'amz-format' => 'Age', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Maximum Manufacturer Age Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_maxmmnfgwtrecd' => { 'ns' => 'product', 'amz-format' => 'Weight', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Maximum Manufacturer Weight Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_minmmerchantagerecd' => { 'ns' => 'product', 'amz-format' => 'Age', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Minimum Merchant Age Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_minmmnfgagerecd' => { 'ns' => 'product', 'amz-format' => 'Age', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Minimum Manufacturer Age Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_minmmnfgwtrecd' => { 'ns' => 'product', 'amz-format' => 'Weight', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Minimum Manufacturer Weight Recommended', 'type' => 'textbox' },
'amz:prod_toysbaby_mnfgsafetywarning' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Manufacturer Safety Warning', 'type' => 'textbox' },
'amz:prod_toysbaby_mnfgwarrantydscrpt' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'Manufacturer Warranty Description', 'type' => 'textbox' },
'amz:prod_toysbaby_nbrofpieces' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'NumberOfPieces', 'type' => 'number' },
'amz:prod_toysbaby_nbrofplayers' => { 'ns' => 'product', 'amz-format' => 'Players', 'src' => 'amz.toysbaby.babyproducts.json', 'title' => 'NumberOfPlayers', 'type' => 'number' },
'amz:prod_toysbaby_toyawardname' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'child_magazine', 'v' => 'child_magazine' },{ 'p' => 'dr_toys_100_best_child_products', 'v' => 'dr_toys_100_best_child_products' },{ 'p' => 'family_fun_toy_of_the_year_seal', 'v' => 'family_fun_toy_of_the_year_seal' },{ 'p' => 'games_magazine', 'v' => 'games_magazine' },{ 'p' => 'lion_mark', 'v' => 'lion_mark' },{ 'p' => 'national_parenting_approval_award', 'v' => 'national_parenting_approval_award' },{ 'p' => 'oppenheim_toys', 'v' => 'oppenheim_toys' },{ 'p' => 'parents_choice_portfolio', 'v' => 'parents_choice_portfolio' },{ 'p' => 'parents_magazine', 'v' => 'parents_magazine' },{ 'p' => 'toy_wishes', 'v' => 'toy_wishes' },{ 'p' => 'unknown', 'v' => 'unknown' } ], 'src' => 'amz.toysbaby.babyproducts.json', 'type' => 'select', 'title' => 'Toys Baby Toy Award Name', 'list' => 'LIST_TOYSBABY_TOYAWARDNAME' },
'amz:prod_wrls_wrlsaccs_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_antennatype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Antenna Type', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_auxiliary' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Auxiliary', 'type' => 'checkbox' },
'amz:prod_wrls_wrlsaccs_batterypower' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Battery Power', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_batterytype' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Battery Type', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_chargingtime' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Charging Time', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_cmpphnmdls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Compatible Phone Models', 'type' => 'textlist' },
'amz:prod_wrls_wrlsaccs_color' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Color', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_colormap' => { 'ns' => 'product', 'amz-format' => 'Text', 'options' => [ { 'T' => '', 'V' => '' },{ 'p' => 'black', 'v' => 'black' },{ 'p' => 'blue', 'v' => 'blue' },{ 'p' => 'bronze', 'v' => 'bronze' },{ 'p' => 'brown', 'v' => 'brown' },{ 'p' => 'gold', 'v' => 'gold' },{ 'p' => 'gray', 'v' => 'gray' },{ 'p' => 'green', 'v' => 'green' },{ 'p' => 'metallic', 'v' => 'metallic' },{ 'p' => 'off-white', 'v' => 'off-white' },{ 'p' => 'orange', 'v' => 'orange' },{ 'p' => 'pink', 'v' => 'pink' },{ 'p' => 'purple', 'v' => 'purple' },{ 'p' => 'red', 'v' => 'red' },{ 'p' => 'silver', 'v' => 'silver' },{ 'p' => 'white', 'v' => 'white' },{ 'p' => 'yellow', 'v' => 'yellow' } ], 'src' => 'amz.wireless.wirelessaccessories.json', 'type' => 'select', 'title' => 'Color Map', 'list' => 'LIST_BASE_COLORMAP' },
'amz:prod_wrls_wrlsaccs_extended' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Extended', 'type' => 'checkbox' },
'amz:prod_wrls_wrlsaccs_itempkgqnty' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'ItemPackageQuantity', 'type' => 'number' },
'amz:prod_wrls_wrlsaccs_kwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Keywords', 'type' => 'textlist' },
'amz:prod_wrls_wrlsaccs_mnfgname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Manufacturer Name', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_refillable' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Refillable', 'type' => 'checkbox' },
'amz:prod_wrls_wrlsaccs_slim' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Slim', 'type' => 'checkbox' },
'amz:prod_wrls_wrlsaccs_solar' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Solar', 'type' => 'checkbox' },
'amz:prod_wrls_wrlsaccs_standbytime' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Standby Time', 'type' => 'textbox' },
'amz:prod_wrls_wrlsaccs_talktime' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessaccessories.json', 'title' => 'Talk Time', 'type' => 'textbox' },
'amz:prod_wrls_wrlsdwnlds_addlfeatures' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessdownloads.json', 'title' => 'Additional Features', 'type' => 'textbox' },
'amz:prod_wrls_wrlsdwnlds_applnvrsn' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessdownloads.json', 'title' => 'Application Version', 'type' => 'textbox' },
'amz:prod_wrls_wrlsdwnlds_cmpphnmdls' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessdownloads.json', 'title' => 'Compatible Phone Models', 'type' => 'textlist' },
'amz:prod_wrls_wrlsdwnlds_kwords' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessdownloads.json', 'title' => 'Keywords', 'type' => 'textlist' },
'amz:prod_wrls_wrlsdwnlds_mnfgname' => { 'ns' => 'product', 'amz-format' => 'Text', 'src' => 'amz.wireless.wirelessdownloads.json', 'title' => 'Manufacturer Name', 'type' => 'textbox' },
'amz:search_terms' => { 'amz-attr' => 'search-terms', 'ns' => 'product', 'src' => 'amz.clothing.json', 'title' => 'Search Terms', 'type' => 'textlist' },
'variation:color' => { 'ns' => 'product', 'xmlattrib' => 'Color', 'amz-format' => 'ColorSpecification', 'src' => 'amz.autopart.autoaccessorymisc.json', 'type' => 'hidden', 'vkey' => 'Color' },
'variation:size' => { 'ns' => 'product', 'amz-format' => 'Verbatim', 'src' => 'amz.autopart.autoaccessorymisc.json', 'type' => 'hidden', 'vkey' => 'Size' },

## END DYNAMIC AMAZON FIELDS ##
# 'amz:product_type' =>  { 'src' => 'amphidex:AR_223932', 'type' => 'legacy' },
'amz:prts' =>  { 'hint' => 'Select the partitions which this product will be allowed to syndicate from (note: you must select at least one partition for this field to work).', 'type' => 'prtchooser', 'title' => 'Amazon Syndication Restrict to Partitions' },
'amz:qty' =>  { 'sku'=>1, 'hint' => 'The maximum quantity to send/reserve to inventory. Set to -1 to send all inventory without reserving any.', 'type' => 'number', 'title' => 'Amazon Max Inventory' },
#'amz:quantity' =>  { 'src'=>'toolusa:AA-10054', 'type' => 'legacy' },
'amz:restock_date' =>  { 'sku'=>1, 'hint' => 'Date that the product will be restocked to Amazon (YYYYMMDD)', 'type' => 'date', 'title' => 'Amazon Restock Date (YYYYMMDD)' },
#'amz:search_term_1' =>  { 'src' => 'summitfashions:YMR177020', 'type' => 'legacy' },
#'amz:search_term_2' =>  { 'src' => 'summitfashions:YAC09', 'type' => 'legacy' },
#'amz:search_term_3' =>  { 'src' => 'summitfashions:YAC09', 'type' => 'legacy' },
#'amz:search_term_4' =>  { 'src' => 'summitfashions:YAC09', 'type' => 'legacy' },
#'amz:search_term_5' =>  { 'src' => 'summitfashions:YAC09', 'type' => 'legacy' },
'amz:search_terms' =>  { 'src'=>'2bhip:A10-00', 'type' => 'legacy' },

#'amz:search_terms1' =>  { 'src' => 'mandwsales:11002', 'type' => 'legacy' },
#'amz:search_terms2' =>  { 'src' => 'mandwsales:11002', 'type' => 'legacy' },
#'amz:search_terms3' =>  { 'src' => 'mandwsales:458415', 'type' => 'legacy' },
#'amz:search_terms4' =>  { 'src' => 'mandwsales:788840', 'type' => 'legacy' },
#'amz:search_terms5' =>  { 'src' => 'mandwsales:11002', 'type' => 'legacy' },
#'amz:search_terms_1' =>  { 'src' => '2bhip:BAG21', 'type' => 'legacy' },
#'amz:search_terms_2' =>  { 'src' => '2bhip:BAG21', 'type' => 'legacy' },
#'amz:search_terms_3' =>  { 'src' => '2bhip:BAG21', 'type' => 'legacy' },
#'amz:search_terms_4' =>  { 'src' => '2bhip:BAG21', 'type' => 'legacy' },
#'amz:search_terms_5' =>  { 'src' => '2bhip:BAG21', 'type' => 'legacy' },
#'amz:so_amount1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_donotship1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_donotship2' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_locale1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_locale2' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_service_level1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_service_level2' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_ship_option1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_ship_option2' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_shipoption1' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_shipoption2' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },
#'amz:so_type' =>  { 'src' => 'mcdc:TEST-AMZ-ASIN', 'type' => 'legacy' },

'seo:noindex'=> { 'ns'=>'product', 'type'=>'boolean', 'src'=>'SEO Hint to noindex' },

'amz:thesaurus' =>  { 'src' => '2bhip:A10-00', 'type' => 'legacy' },
'amz:ts' =>  { 'type' => 'checkbox' },
'amzpa:category' =>  { 'maxlength' => 128, 'title' => 'Amazon Product Ads Category', 'type' => 'text', 'size' => 60 },
'amzpa:note' =>  { 'maxlength' => 100, 'title' => 'Amazon Product Ads Syndication Note', 'type' => 'text', 'size' => 60 },
'amzpa:prod_desc' =>  { 'title' => 'Amazon Product Ads Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 80 },
'amzpa:prod_name' =>  { 'maxlength' => 100, 'title' => 'Amazon Product Ads Title', 'type' => 'text', 'size' => 60 },
'amzpa:ts' =>  { 'src' => '2bhip:A10-00', 'type' => 'checkbox' },
'amzsearch_terms2' =>  { 'src' => 'mandwsales:458415', 'type' => 'legacy' },
'authnet:html' =>  { 'ns' => 'profile', 'title' => 'Authorize.net Seal Code', 'type' => 'textarea' },
'bbbonline:id' =>  { 'ns' => 'profile', 'type' => 'textbox', 'title' => 'BBB ID' },
'googlets:search_account_id' =>  { 'ns' => 'profile', 'type' => 'textbox', 'title' => 'Google Trusted Stores Search Account ID' },
'googlets:badge_code' =>  { 'ns' => 'profile', 'type' => 'textarea', 'title' => 'Google Trusted Stores Decal/Badge Code' },
'googlets:chkout_code' =>  { 'ns' => 'profile', 'type' => 'textarea', 'title' => 'Google Trusted Stores Checkout Code' },
'become:category' =>  { 'src' => 'thechessstore:PRD45JF', 'type' => 'legacy' },
'become:note' =>  { 'maxlength' => 100, 'title' => 'Become.com Syndication Note', 'type' => 'text', 'size' => 60 },
'become:ts' =>  { 'type' => 'checkbox', 'title' => 'Become.com syndication enabled' },
'become:is_hot' =>  { 'type' => 'checkbox', 'title' => 'Become.com "Is Hot"' },
'bestseller' =>  { 'src' => '2bhip:AA5', 'type' => 'legacy' },
'bing:prod_name' =>  { 'maxlength' => 200, 'hint' => 'Used instead of Zoovy defined product name.', 'title' => 'Bing Product Title', 'type' => 'text', 'size' => 60 },
'bing:category' =>  { 'title' => 'Bing Category #', 'type' => 'number' },
'bing:categorypath' =>  { 'hint' => 'This will override bing:category', 'title' => 'Bing Category Path', 'type' => 'textbox' },
'bing:note' =>  { 'maxlength' => 100, 'title' => 'Bing Syndication Note', 'type' => 'text', 'size' => 60 },
'bing:prod_desc' =>  { 'title' => 'Bing Product Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 80 },
'bing:ship_cost1' =>  { 'type' => 'currency', 'title' => 'Bing.com Flat Shipping Cost (first item)' },
'bing:ts' =>  { 'type' => 'checkbox', 'title' => 'Bing syndication enabled' },
'bizrate:bid' =>  { 'src' => 'affordableproducts:3AHBON1', 'type' => 'legacy' },
'bizrate:category' =>  { 'src' => 'affordableproducts:3AHBON1', 'type' => 'legacy' },
'bizrate:note' =>  { 'maxlength' => 100, 'title' => 'Bizrate Syndication Note', 'type' => 'text', 'size' => 60 },
'bizrate:ts' =>  { 'type' => 'checkbox', 'title' => 'Bizrate syndication enabled' },
'blog:url' =>  { 'maxlength' => 200, 'ns' => 'profile', 'type' => 'textbox', 'title' => 'Blog URL', 'size' => 100 },
'buy:category' =>  { 'src' => 'andreasinc:DVD-3800', 'type' => 'legacy' },
'buy:dbmap' =>  { 'src' => 'beautystore:GLO-LSNATLT', 'type' => 'legacy' },
'buy:listingid' =>  { 'src' => 'andreasinc:DVD-3800', 'type' => 'legacy' },
'buy:store_code' =>  { 'src' => 'tarasi:100CORONA', 'type' => 'legacy' },
'buy:ts' =>  { 'src' => 'andreasinc:DVD-3800', 'type' => 'checkbox' },
'bestbuy:ts' =>  { 'type' => 'checkbox', title=>"BestBuy Syndication" },
'buycom:ts' =>  { 'type' => 'checkbox', title=>"Buy.com Syndication"  },
'buycom:age_range' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:agesegment' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:apparel_material' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:apparelmaterial' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:assembled_dimension_height_in' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:assembled_dimension_length_in' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:assembled_dimension_width_in' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:assembly_level' =>  { 'src' => 'beachmart:WRB5002', 'type' => 'legacy' },
'buycom:assembly_required' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:batteries_required' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:battery_quantity' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:battery_type_required' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:bowl_type' =>  { 'src' => 'toynk:EMI-SB12_BLACK-AS12', 'type' => 'legacy' },
'buycom:category' =>  { 'src' => 'andreasinc:G83702', 'type' => 'legacy' },
'buycom:categoryid' =>  { 'type' => 'textbox', 'title' => 'Buy.com CategoryID' },
'buycom:chair_type' =>  { 'src' => 'beachmart:WRB5002', 'type' => 'legacy' },
'buycom:character_name' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:character_series' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:character_series_type' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:color' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:color_class' =>  { 'src' => 'beachmart:WRBU747', 'type' => 'legacy' },
'buycom:colorclass' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:costumes_age_segment' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_color' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_color_class' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_costume_theme' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_gender' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_material' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_occasion' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_Women' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_boys' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_children' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_girls' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_infant' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_infants' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_junior' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_men' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_misses' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_size_toddler' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:costumes_sizecode_child' =>  { 'src' => 'cubworld:CHIC101', 'type' => 'legacy' },
'buycom:dbmap' =>  { 'src' => 'andreasinc:FLUTE17', 'type' => 'legacy' },
'buycom:error' =>  { 'src' => 'andreasinc:G83702', 'type' => 'legacy' },
'buycom:eyeweartype' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:furniture_material' =>  { 'src' => 'beachmart:WRB5002', 'type' => 'legacy' },
'buycom:furniture_style' =>  { 'src' => 'beachmart:WRB5002', 'type' => 'legacy' },
'buycom:game_type' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:gender' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:glass_type' =>  { 'src' => 'toynk:EMI-SB12_BLACK-AS12', 'type' => 'legacy' },
'buycom:listingid' =>  { 'src' => 'beautystore:D-3260', 'type' => 'legacy' },
'buycom:material' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:plate_type' =>  { 'src' => 'toynk:EMI-SB12_BLACK-AS12', 'type' => 'legacy' },
'buycom:prod_age_segment' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_color' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_color_class' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_desc' =>  { 'src' => 'beautystore:GLO-LSNATLT', 'type' => 'legacy' },
'buycom:prod_gender' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_hat_type' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_jacket_buttons' =>  { 'src' => 'cubworld:1123', 'type' => 'legacy' },
'buycom:prod_mlb_team' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:prod_neck_type' =>  { 'src' => 'cubworld:CHIC379', 'type' => 'legacy' },
'buycom:prod_nfl_team' =>  { 'src' => 'cubworld:CHIC465', 'type' => 'legacy' },
'buycom:prod_shipleadtime' =>  { 'title' => 'Buycom Shipping Lead Time', 'type' => 'textbox' },
'buycom:prod_size' =>  { 'src' => 'cubworld:KIDS10021', 'type' => 'legacy' },
'buycom:safety_warning' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:ship_cost1' =>  { 'title' => 'Buycom Shipping Price', 'type' => 'textbox' },
'buycom:ship_cost1if' =>  { 'src' => 'tting:N310-13GO', 'type' => 'legacy' },
'buycom:shipexp_cost1' =>  { 'title' => 'Buycom Expedited Shipping Price', 'type' => 'textbox' },
'buycom:ships_in_original_container' =>  { 'src' => 'brian:HBR-44035-C', 'type' => 'legacy' },
'buycom:shirttype' =>  { 'src' => 'cubworld:CHIC379', 'type' => 'legacy' },
'buycom:size' =>  { 'src' => 'nyciwear:PR61L5AV5Z1', 'type' => 'legacy' },
'buycom:size_boys' =>  { 'src' => 'cubworld:1123', 'type' => 'legacy' },
'buycom:size_men' =>  { 'src' => 'toynk:ICN-10015L-C', 'type' => 'legacy' },
'buycom:size_mens' =>  { 'src' => 'toynk:ICN-70003XL-C', 'type' => 'legacy' },
'buycom:sizecode_men' =>  { 'src' => 'cubworld:CHIC379', 'type' => 'legacy' },
'buycom:sizecode_women' =>  { 'src' => 'toynk:RUB-16499-P', 'type' => 'legacy' },
'buycom:sku' =>  { 'type' => 'textbox', 'sku'=>1 },
'buycom:sleevetype' =>  { 'src' => 'cubworld:CHIC379', 'type' => 'legacy' },
'buycom:toplength' =>  { 'src' => 'cubworld:CHIC379', 'type' => 'legacy' },
'buycom:vehicle_type' =>  { 'src' => 'toynk:POP-NT7810202-G', 'type' => 'legacy' },
'buysafe:ts' =>  { 'src' => 'beachmart:MSRB5915F', 'type' => 'checkbox' },
'cj:category' =>  { 'maxlength' => 75, 'title' => 'Commission Junction Advertiser Category', 'type' => 'text', 'size' => 60 },
'cj:merchandisetype' =>  { 'maxlength' => 75, 'title' => 'Commission Junction Merchandise Type', 'type' => 'text', 'size' => 60 },
'cj:ts' =>  { 'type'=>'checkbox',  'title' => 'Commission Junction syndication enabled' },
'db:id' =>  { 'src' => '1stproweddingalbums:', 'type' => 'constant' },
'dijipop:ts' =>  { 'type' => 'checkbox', 'title' => 'DijiPop syndication enabled' },
'ebates:ts' =>  { 'src' => 'beachmart:ACAU320-57', 'type' => 'legacy' },
'ebay:attributeset' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type' => 'hidden' },
'ebay:itemspecifics' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type' => 'hidden' },
'ebay:base_weight' =>  { 'properties'=>1, 'grp'=>'ebay.listing', 'ns'=>'product', 'hint' => 'Used to specify an alternate weight for an eBay item', 'custom' => 1, 'title' => 'eBay specific weight', 'type' => 'text' },
'ebay:category' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'src' => '1stproweddingalbums:N80', 'type' => 'ebay/category' },
'ebay:category2' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'src' => '1stproweddingalbums:N80', 'type' => 'ebay/category' },
'ebay:conditionid' => { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>"select",
	title=>"eBays unified site-wide condition id", hint=>"not all values are applicable for all categories, however ebay began transitioning all categories to this unified notation in July 2010",
		'options'=>[
			{ p=>"New/BrandNew/withBox", v=>"1000" },
			{ p=>"*New/Other/noBox", v=>"1500" },
			{ p=>"*New/withDefects", v=>"1750" },
			{ p=>"Refurbished/by Mfg", v=>"2000" },
			{ p=>"Refurbished/by Seller", v=>"2500" },
			{ p=>"Used/LikeNew/PreOwned", v=>"3000" },
			{ p=>"Very Good", v=>"4000" },
			{ p=>"Good", v=>"5000" },
			{ p=>"Acceptable", v=>"6000" },
			{ p=>"Not Working/For Parts", v=>"7000" },
			]},
'ebay:ext_pid_type' =>  { 'src' => '888knivesrus:CSVDWEP', 'type' => 'hidden' },
'ebay:ext_pid_value' =>  { 'src' => '888knivesrus:CSVDWEP', 'type' => 'hidden' },
'ebay:fixed_price' =>  { type=>'currency',legacy=>"ebay:buyitnow,ebay:price",ns=>'product',hint=>"eBay Item Fixed Price" },
'ebay:fixed_qty' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>'number',hint=>"eBay Fixed Quantity" },
'ebay:minsellprice' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'hint' => 'Putting an amount in this field will enable the eBay second chance offer feature for any bids above the minimum sell price.', 'type' => 'textbox', 'title' => 'eBay Minimum Sell Price', 'size' => 10 },
'ebay:list_private' =>  { title=>'Create Private Listings', 'ns'=>'product', 'type' => 'boolean' },
'ebay:prod_desc' =>  { ns=>'wizard', 'hint' => 'separate description specific for eBay (most templates will require updates to use this)', 'title' => 'eBay Product Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 50 },
'ebay:prod_ebay_promo_text' =>  { ns=>'wizard', 'src' => 'alternativedvd:3DS_ANICROSS3DS', 'type' => 'legacy' },
'ebay:prod_image1' =>  { 'ns'=>'wizard',  'type' => 'image', 'title' => 'eBay Primary Image' },
'ebay:prod_image2' =>  { 'ns'=>'wizard',  'hint' => 'Please enter a picture for your product.', 'origin' => 'lagniappe/WIZARD.~mb_wizard', 'type' => 'image', 'title' => 'Image Collage 1' },
'ebay:prod_image3' =>  { 'ns'=>'wizard',  'hint' => 'Please enter a picture for your product.', 'origin' => 'lagniappe/WIZARD.~mb_wizard', 'type' => 'image', 'title' => 'Image Collage 2' },
'ebay:prod_thumb' =>  { 'ns'=>'wizard', 'type' => 'image', 'title' => 'eBay Thumbnail Image' },
'ebay:productid' =>  { 'src' => '1stproweddingalbums:SA5R7BL12', 'type' => 'hidden' },
'ebay:profile' =>  { 'src' => 'andreasinc:MUSICSTAND5', 'type' => 'special' },
'ebay:qty' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>'number',hint=>"eBay Auction Quantity" },
'ebay:reserve_price' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>"currency",hint=>'Required for an Auction Listing', legacy=>"ebay:reserve",ns=>'product',hint=>"eBay Auction Reserve Price"},
'ebay:secondchance' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'src' => 'redford:FS-MRDS190', 'type' => 'currency', title=>'AutoSecond Chance Price' },
'ebay:ship_cost1' => { 'grp'=>'ebay.listing', type=>"currency",loadfrom=>"zoovy:ship_cost1",ns=>"product",title=>"eBay Fixed Shipping Cost (first item)",hint=>"Defaults to zoovy:ship_cost1. To simply markup the shipping for eBay use ebay:ship_markup instead." },
'ebay:ship_cost2' => { 'grp'=>'ebay.listing', type=>"currency",loadfrom=>"zoovy:ship_cost2",ns=>"product",title=>"eBay Fixed Shipping Cost (Additional Item)",hint=>"defaults to zoovy:ship_cost2 (additional fixed price item)"},
'ebay:ship_markup' => { 'grp'=>'ebay.listing', type=>"currency",loadfrom=>"zoovy:ship_markup",ns=>"profile",title=>"eBay Fixed Shipping Markup",hint=>"An additional amount in dollars that will be added to fixed price shipping cost for both first and second items. Particularly useful when ebay:ship_cost1, and ebay:ship_cost2 are left blank, so zoovy:ship_cost1, and zoovy:ship_cost2 are used. For eBay calculated shipping methods this field is ignored - however ebay:base_weight can be used to send an alternate (higher) weight for eBay thus accomplishing the same result."},
'ebay:ship_can_cost1' => { 'grp'=>'ebay.listing', type=>"currency",title=>"eBay Fixed Shipping Cost to Canada", loadfrom=>"zoovy:ship_can_cost1",ns=>"product"},
'ebay:ship_can_cost2' => { 'grp'=>'ebay.listing', type=>"currency",title=>"eBay Fixed Shipping Cost (add. items) to Canada",loadfrom=>"zoovy:ship_can_cost2",ns=>"product"},
'ebay:ship_int_cost1' => { 'grp'=>'ebay.listing', type=>"currency",title=>"eBay Fixed Shipping Cost to International",loadfrom=>"zoovy:ship_int_cost1",ns=>"product"},
'ebay:ship_int_cost2' => { 'grp'=>'ebay.listing', type=>"currency",title=>"eBay Fixed Shipping Cost (add. items) to International",loadfrom=>"zoovy:ship_int_cost2",ns=>"product"},
	'ebay:ship_dominstype' => { 
		type=>'select',  grp=>'ebay.shipping', 
		options=>[
			{ p=>'NotOffered', v=>'NotOffered' },
			{ p=>'IncludedInShippingHandling', v=>'IncludedInShippingHandling' },
			{ p=>'Optional', v=>'Optional' },
			{ p=>'Required', v=>'Required' },
			], 
		},
'ebay:ship_dominsfee' => { type=>"currency",title=>"eBay Domestic Insurance Fee",ns=>"profile", 'grp'=>'ebay.shipping'},
'ebay:ship_intinstype' => { maxlength=>5,title=>"eBay International Insurance Setting",ns=>"profile", 'grp'=>'ebay.shipping', 'options' => [ { 'p' => 'NotOffered', 'v' => 'NotOffered' }, { 'p' => 'IncludedInShippingHandling', 'v' => 'IncludedInShippingHandling' }, { 'p' => 'Optional', 'v' => 'Optional' }, { 'p' => 'Required', 'v' => 'Required' } ], 'grp' => 'ebay.shipping', 'type' => 'select' },
'ebay:ship_markup' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type' => 'currency', title=>"eBay Fixed Shipping Markup",hint=>"An additional amount in dollars that will be added to fixed price shipping cost for both first and second items. Particularly useful when ebay:ship_cost1, and ebay:ship_cost2 are left blank, so zoovy:ship_cost1, and zoovy:ship_cost2 are used. For eBay calculated shipping methods this field is ignored - however ebay:base_weight can be used to send an alternate (higher) weight for eBay thus accomplishing the same result." },
'ebay:skypeid' =>  { 'maxlength' => 50, 'ns' => 'profile', 'grp' => 'ebay.profile', 'type' => 'textbox', 'size' => 20 },
'ebay:start_price' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>"currency",required=>1,legacy=>"ebay:startprice",ns=>'product',hint=>"eBay Auction Start Price" },
'ebay:startprice' =>  { 'legacy'=>1, 'src' => '1stproweddingalbums:N80', 'type' => 'legacy' },
'ebay:storecat' => { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>'ebay/storecat',ns=>'product',loadrom=>"navcat:ebay_storecat",hint=>"eBay Store Category One"},
'ebay:storecat2' => { 'grp'=>'ebay.listing', 'ns'=>'product', 'type'=>'ebay/storecat',ns=>'product',hint=>"eBay Store Category Two"},
'ebay:subtitle' =>  { 'grp'=>'ebay.listing', 'ns'=>'product', 'maxlength' => 55, 'type' => 'textbox', 'title' => 'eBay SubTitle' },
'ebay:title' =>  { 'properties'=>1, 'grp'=>'ebay.listing', 'ns'=>'product', 'maxlength' => 80, 'type' => 'textbox', 'title' => 'eBay Title', 'minlength' => 1 },
'ebay:ts' =>  { 'src' => '2bhip:A12', 'type' => 'checkbox' },
 
'etilize:category' =>  { 'src' => 'patti:41U3074', 'type' => 'legacy' },
'etilize:mfgpartno' =>  { 'src' => 'patti:41U3074', 'type' => 'legacy' },
'etilize:product_id' =>  { 'src' => 'patti:41U3074', 'type' => 'legacy' },
'etilize:tech_specs' =>  { 'src' => 'patti:41U3074', 'type' => 'legacy' },
'g:brand' =>  { 'src' => '2bhip:TS339-00', 'type' => 'legacy' },
'g:product_type' =>  { 'src' => '2bhip:A10-00', 'type' => 'legacy' },
'gbase:base_price' =>  { 'format' => 'currency', 'hint' => 'Putting an amount in this field will override the GoogleBase Price', 'type' => 'number', 'title' => 'GoogleBase Override Price', 'size' => 10 },
'gbase:note' =>  { 'maxlength' => 100, 'title' => 'GoogleBase Syndication Note', 'type' => 'text', 'size' => 60 },
'gbase:prod_desc' =>  { 'maxlength' => 100, 'title' => 'GoogleBase Product Title Description', 'type' => 'text', 'size' => 60 },
'gbase:prod_name' =>  { 'maxlength' => 75, 'title' => 'GoogleBase Product Title', 'type' => 'text', 'size' => 60 },
'gbase:prod_name_before_options' =>  { 'maxlength' => 75, 'title' => 'GoogleBase Product Title (Before Options)', 'type' => 'text', 'size' => 60 },
'gbase:prod_upc' =>  { 'hint' => 'UPC sent to Googlebase (if different than zoovy:prod_upc)', 'name' => 'GoogleBase Product UPC', 'product' => 1, 'type' => 'textbox' },
'gbase:product_name' =>  { 'src' => 'qualityoverstock:S1068985', 'type' => 'legacy' },
'gbase:product_type' =>  { 'maxlength' => 125, 'title' => 'GoogleBase Product Type', 'type' => 'text', 'size' => 60 },
'gbase:product_type2' =>  { 'maxlength' => 75, 'title' => 'GoogleBase Product Type (Secondary)', 'type' => 'text', 'size' => 60 },
'gbase:product_type3' =>  { 'maxlength' => 75, 'title' => 'GoogleBase Product Type (Trietary)', 'type' => 'text', 'size' => 60 },
'gbase:product_type4' =>  { 'maxlength' => 75, 'title' => 'GoogleBase Product Type (Quadrinary)', 'type' => 'text', 'size' => 60 },
'gbase:product_type5' =>  { 'src' => 'gssstore:OCCLUX-SSLDMSO', 'type' => 'legacy' },
'gbase:product_type6' =>  { 'src' => 'gssstore:OCCLUX-SSLDMSO', 'type' => 'legacy' },
'gbase:sku_name' =>  { 'maxlength' => 75, 'sku' => 1, 'title' => 'GoogleBase SKU Title', 'type' => 'text', 'size' => 60 },
'gbase:ts' =>  { 'type' => 'checkbox', 'title' => 'GoogleBase syndication enabled' },
'gc:blocked' =>  { 'on' => 1, 'off' => 0, 'type' => 'cb', 'title' => 'Google Checkout Blocked' },
'hsn:base_cost' =>  { 'type' => 'currency', 'title' => 'HSN Product Cost' },
'hsn:category' =>  { 'src' => 'toynk:POP-NT7810202-G', 'type' => 'legacy' },
'hsn:prod_desc' =>  { 'title' => 'Home Shopping Network Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 80 },
'hsn:ts' =>  { 'type' => 'checkbox', 'title' => 'Home Shopping Network Syndication Enabled' },
'hsn:mfg_certificate' =>  { 'title' => 'HSN Manufacturer Certificate', 'type' => 'textbox', 'size' => '25', hint=>'Certificate stored on HSN server'},
'ibuystores:prod_url_pdf_specs' =>  { 'src' => 'ibuystores:NEP0651', 'type' => 'legacy' },
'is:bestseller' =>  { 'type'=>'checkbox', 'popular'=>1, 'bit' => 11, 'tag' => 'IS_BESTSELLER' },
# 'is:clearance' =>  {  'src' => 'affordableproducts:3CO92GS', 'type' => 'legacy' },
'is:discontinued' =>  { 'type'=>'checkbox', 'popular'=>1, 'bit' => 9, 'tag' => 'IS_DISCONTINUED' },
'is:fresh' =>  { 'type'=>'checkbox', 'popular'=>1, 'bit' => 0, 'tag' => 'IS_FRESH' },
'is:haserrors' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 2, 'tag' => 'IS_HASERRORS' },
'is:colorful' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 4, 'tag' => 'IS_COLORFUL'},
'is:sizeable' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 5, 'tag' => 'IS_SIZEABLE'},
'is:download' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 6, 'tag' => 'IS_DOWNLOAD'},
'is:needreview' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 1, 'tag' => 'IS_NEEDREVIEW' },
'is:download'=> { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit'=>6, 'tag'=>'IS_DOWNLOAD' },
'is:newarrival' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 14, 'tag' => 'IS_NEWARRIVAL' },
'is:openbox' =>  { 'type'=>'checkbox', 'popular'=>1 },
'is:preorder' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 8, 'tag' => 'IS_PREORDER' },
'is:refurb' =>  { 'type'=>'checkbox', 'src' => 'beechmontporsche:996-362-142-04', 'type' => 'legacy' },
'is:sale' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 12, 'tag' => 'IS_SALE' },
'is:shipfree' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 13, 'tag' => 'IS_SHIPFREE' },
'is:specialorder' =>  { 'type'=>'checkbox', 'popular'=>1, 'type'=>'checkbox', 'bit' => 10, 'tag' => 'IS_SPECIALORDER' },

'is:user1' =>  {  'type'=>'checkbox', 'bit' => 17, 'tag' => 'IS_USER1' },
'is:user2' =>  {  'type'=>'checkbox', 'bit' => 18, 'tag' => 'IS_USER2' },
'is:user3' =>  {  'type'=>'checkbox', 'bit' => 19, 'tag' => 'IS_USER3' },
'is:user4' =>  {  'type'=>'checkbox', 'bit' => 20, 'tag' => 'IS_USER4' },
'is:user5' =>  {  'type'=>'checkbox', 'bit' => 21, 'tag' => 'IS_USER5' },
'is:user6' =>  {  'type'=>'checkbox', 'bit' => 22, 'tag' => 'IS_USER6' },
'is:user7' =>  {  'type'=>'checkbox', 'bit' => 23, 'tag' => 'IS_USER7' },
'is:user8' =>  {  'type'=>'checkbox', 'bit' => 24, 'tag' => 'IS_USER8' },
'is:user9' =>  {  'type'=>'checkbox', 'bit' => 25, 'tag' => 'IS_USER9' },
'is:user10' =>  {  'type'=>'checkbox', 'bit' => 26, 'tag' => 'IS_USER10' },
'is:user11' =>  {  'type'=>'checkbox', 'bit' => 27, 'tag' => 'IS_USER11' },
'is:user12' =>  {  'type'=>'checkbox', 'bit' => 28, 'tag' => 'IS_USER12' },
'is:user12' =>  {  'type'=>'checkbox', 'bit' => 29, 'tag' => 'IS_USER13' },
'is:user14' =>  {  'type'=>'checkbox', 'bit' => 30, 'tag' => 'IS_USER14' },
'is:user15' =>  {  'type'=>'checkbox', 'bit' => 0, 'tag' => 'IS_USER15' },
'is:user16' =>  {  'type'=>'checkbox', 'bit' => 0, 'tag' => 'IS_USER16' },

'jellyfish:commission' =>  { 'src' => 'bamtar:XGP2-0953', 'type' => 'legacy' },
'jellyfish:ts' =>  { 'src' => '2bhip:A10-00', 'type' => 'legacy' },
'linkshare:ts' =>  { 'type' => 'checkbox', 'title' => 'Linkshare syndication enabled' },
'media:ts' =>  { 'src' => 'digmodern:0515057', 'type' => 'legacy' },
'navcat:meta' =>  { 'hint' => 'This field is dynamically populated by the syndication engine and contains the category linked to the product by the navigation category', 'type' => 'generated' },
'newegg:prod_desc' =>  { 'title' => 'Newegg Product Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 80 },
'newegg:shipping_type' =>  { 'options' => [ { 'p' => 'Free', 'v' => 'Free' }, { 'p' => 'Other', 'v' => 'Other' } ], 'type' => 'select', 'title' => 'Newegg Shipping Type' },
'newegg:ts' =>  { 'type' => 'checkbox', 'title' => 'Newegg Syndication Enabled' },
'nextag:cpc_rate' =>  { 'src' => 'andreasinc:110100', 'type' => 'legacy' },
'nextag:max_cpc' =>  { 'src' => 'andreasinc:110100', 'type' => 'legacy' },
'nextag:muze_id' =>  { 'src' => 'andreasinc:110100', 'type' => 'legacy' },
'nextag:note' =>  { 'maxlength' => 100, 'title' => 'Nextag Syndication Note', 'type' => 'text', 'size' => 60 },
'nextag:prod_name' =>  { 'maxlength' => 200, 'type' => 'text', 'title' => 'NexTag Product Name', 'size' => '60' },
'nextag:ts' =>  { 'type' => 'checkbox', 'title' => 'NexTag syndication enabled' },
'paypalec:blocked' =>  { 'type' => 'checkbox', 'title' => 'Block Paypal Express Checkout' },
'pricegrabber:category' =>  { 'src' => 'gogoods:29429', 'type' => 'legacy' },
'pricegrabber:condition' =>  { 'src' => 'andreasinc:DHAM-SBA', 'type' => 'legacy' },
'pricegrabber:masterid' =>  { 'src' => 'andreasinc:DHAM-SBA', 'type' => 'legacy' },
'pricegrabber:note' =>  { 'maxlength' => 100, 'title' => 'PriceGrabber Syndication Note', 'type' => 'text', 'size' => 60 },
'pricegrabber:ship_fixedamt' =>  { 'src' => 'gogoods:29429', 'type' => 'legacy' },
'pricegrabber:ts' =>  { 'type' => 'checkbox', 'title' => 'Pricegrabber syndication enabled' },
'product:user:prod_store_desc' =>  { 'src' => 'triplelux:25626', 'type' => 'legacy' },
'pronto:category' =>  { 'grp' => 'pronto', 'type' => 'textbox', 'title' => 'Pronto Category ID' },
'pronto:category_id' =>  { 'src' => 'tarasi:100CORONA', 'type' => 'legacy' },
'pronto:note' =>  { 'maxlength' => 100, 'title' => 'Pronto Syndication Note', 'type' => 'text', 'size' => 60 },
'pronto:prod_name' =>  { 'maxlength' => 100, 'title' => 'Pronto Title', 'type' => 'text', 'size' => 60 },
'pronto:ts' =>  { 'type' => 'checkbox', 'title' => 'Pronto syndication enabled' },
'sas:cat' =>  { 'src' => 'designed2bsweet:PAPPLATE62', 'type' => 'legacy' },
'sas:merc_id' =>  { 'src' => 'designed2bsweet:PAPPLATE62', 'type' => 'legacy' },
'sas:product_url' =>  { 'src' => 'designed2bsweet:DUCKY9', 'type' => 'legacy' },
'sas:sub_cat' =>  { 'src' => 'designed2bsweet:PAPPLATE62', 'type' => 'legacy' },
'sas:ts' =>  { 'src' => '2bhip:A10-00', 'type' => 'legacy' },
'sears:note' =>  { 'maxlength' => 100, 'title' => 'Sears Syndication Note', 'type' => 'text', 'size' => 60 },
'sears:prod_desc' =>  { 'title' => 'Sears Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 80 },
'sears:ts' =>  { 'type' => 'checkbox', 'title' => 'Sears Syndication Enabled' },
'sears:ship_cost' =>  { 'title' => 'Sears Shipping Price', 'type' => 'textbox' },
'sears:shipexp_cost' =>  { 'title' => 'Sears Expedited Shipping Price', 'type' => 'textbox' },
'sears:freeship_date' =>  {'hint' => 'Date free shipping will commence on Sears (YYYYMMDD)', 'type' => 'date', 'title' => 'Sears Freeship Start Date (YYYYMMDD)' },
'shopcom:ts' =>  { 'src' => 'designed2bsweet:PAPPLATE62', 'type' => 'legacy' },
'shopping:category' =>  { 'src' => 'fortewebproperties:NDC-SPLASH', 'type' => 'legacy' },
'shopping:inventory' =>  { 'src' => 'beachmart:MSRB5915F', 'type' => 'legacy' },
'shopping:note' =>  { 'maxlength' => 100, 'title' => 'Shopping.com Syndication Note', 'type' => 'text', 'size' => 60 },
'shopping:prodtype' =>  { 'src' => 'alloceansports:HASH0XB7C3D418', 'type' => 'legacy' },
'shopping:ship_2day' =>  { 'src' => 'yocaps:RCSLARA-SOBLBL', 'type' => 'legacy' },
'shopping:ship_ground' =>  { 'src' => 'beachmart:MSRB5915F', 'type' => 'legacy' },
'shopping:ts' =>  { 'type' => 'checkbox', 'title' => 'Shopping.com syndication enabled' },
'shopzilla:category' =>  { 'src' => 'sfplanet:C-NIKS6-U2', 'type' => 'legacy' },
'shopzilla:promo_text' =>  { 'title' => 'Shopzilla Promo Text', 'type' => 'text' },
'smarter:ts' =>  { 'src' => '2bhip:A101', 'type' => 'legacy' },
'thefind:note' =>  { 'maxlength' => 100, 'title' => 'TheFind Syndication Note', 'type' => 'text', 'size' => 60 },
'thefind:ts' =>  { 'type' => 'checkbox', 'title' => 'TheFind syndication enabled' },
'trustwave:sealhtml' =>  { 'ns' => 'profile', 'title' => 'TrustWave HTML Seal Code', 'type' => 'textarea' },
'twitter:userid' =>  { 'ns' => 'profile', 'hint' => 'example: zoovyinc', 'title' => 'Twitter UserID', 'type' => 'text' },
'upsellit:html' =>  { 'ns' => 'profile', 'title' => 'UpSell IT Seal Code', 'type' => 'textarea' },
'user:decal1' =>  { 'ns' => 'profile', 'title' => 'User Decal #1', 'type' => 'textarea' },
'user:decal2' =>  { 'ns' => 'profile', 'title' => 'User Decal #2', 'type' => 'textarea' },
'user:decal3' =>  { 'ns' => 'profile', 'title' => 'User Decal #3', 'type' => 'textarea' },
'user:decal4' =>  { 'ns' => 'profile', 'title' => 'User Decal #4', 'type' => 'textarea' },
'user:decal5' =>  { 'ns' => 'profile', 'title' => 'User Decal #5', 'type' => 'textarea' },
'us1:ts' => { 'type'=>'checkbox', name=>'User Application 1 - Syndication' },
'us2:ts' => { 'type'=>'checkbox', name=>'User Application 2 - Syndication' },
'us3:ts' => { 'type'=>'checkbox', name=>'User Application 3 - Syndication' },
'us4:ts' => { 'type'=>'checkbox', name=>'User Application 4 - Syndication' },
'us5:ts' => { 'type'=>'checkbox', name=>'User Application 5 - Syndication' },
'us6:ts' => { 'type'=>'checkbox', name=>'User Application 6 - Syndication' },
'web:prod_domain' =>  { 'hint' => 'A domain name. Any attempt to access this product from a different domain will result in a redirect.', 'title' => 'Product Domain', 'type' => 'text', 'product' => 1 },
'web:prod_domains_allowed' =>  { 'hint' => 'List of domains this product is allowed for', 'title' => 'Allowed Domains', 'type' => 'textlist', 'product' => 1 },
'web:prod_domains_blocked' =>  { 'hint' => 'List of domains this product is blocked for', 'title' => 'Blocked Domains', 'type' => 'textlist', 'product' => 1 },
'wishpot:ts' =>  {'type' => 'checkbox', 'title'=>"Wishpot Syndication" },
'youtube:videoid' =>  { 'popular'=>1, 'type' => 'textbox', 'title' => 'YouTube Embedded Video ID', 'size' => 20 },
'zoovy:accessory_products' =>  { 'index'=>'accessory_products', 'title' => 'list of product accessories', 'type' => 'finder' },
'zoovy:asm_bundle_products' =>  {  'origin' => 'beachmart/LAYOUT.~beachmart_p_jsonpogs_20091005', 'type' => 'textbox', 'title' => 'Product Bundles (comma separated list of SKUs)' },
'zoovy:banner_01' =>  {  'origin' => 'zephyrsports/LAYOUT.~newsletter_signup', 'type' => 'image', 'title' => 'banner' },
'zoovy:base_cost' =>  { 'type' => 'currency', 'sku'=>1, 'title'=>'Cost', 'SKUDB'=>'COST' },
'zoovy:base_price' =>  { 'popular'=>1, 'index'=>'base_price', 'type' => 'currency', 'title' => 'Base Price' },
'zoovy:base_weight' =>  {  'popular'=>1, 'type' => 'textbox', 'title' => 'Shipping Weight' },
'zoovy:catalog' =>  { 'src' => '1stproweddingalbums:BMS245', 'type' => 'legacy' },
'zoovy:category' =>  { 'src' => '888knivesrus:BM5BLK', 'type' => 'legacy' },
'zoovy:color' =>  {  'origin' => 'brian/WIZARD.brandx', 'type' => 'hidden', 'title' => undef },
'zoovy:condition' =>  {  'origin' => 'summitfashions/WIZARD.~summit23chart', 'type' => 'textbox', 'title' => 'product:zoovy:condition S' },
'zoovy:cost' =>  { 'src' => 'ebestsourc:DURACELLAA4DURACELL', 'type' => 'legacy' },
'zoovy:dbmap' =>  { 'src' => 'toynk:ICN-70004ST-C', 'type' => 'legacy' },
'zoovy:depth' =>  { 'src' => 'usavem:DMLM30008', 'type' => 'legacy' },
'zoovy:designer' =>  { 'hint' => 'Designer', 'origin' => 'summitfashions/LAYOUT.~p-1tallpicsizechart', 'type' => 'textbox', 'title' => 'Designer' },
'zoovy:digest' =>  { 'src' => '1stproweddingalbums:LIB91TL', 'type' => 'constant' },
'zoovy:domestic_carrier' =>  {  'origin' => 'goshotcamera/WIZARD.~gsc_basic_2', 'type' => 'textbox', 'title' => 'Carrier for 1st Domestic Shipping' },
'zoovy:fl' =>  {  'origin' => 'creative/LAYOUT.~test', 'type' => 'text', 'title' => 'DO NOT USE ME' },
'zoovy:footer_desc' =>  {  'origin' => 'jordan/WIZARD.~breath_wiz', 'type' => 'textarea', 'title' => 'Second Description' },
'zoovy:footer_text' =>  { 'src' => 'stmparts:TLC971928', 'type' => 'legacy' },
'zoovy:gallery' =>  { 'src' => 'irresistables:70-95225', 'type' => 'legacy' },
'zoovy:gender' =>  { 'src' => 'sporks:AUCTIONTEST', 'type' => 'legacy' },
'zoovy:grp_children' =>  { 'popular'=>1, 'hint' => 'When populated indicates this is a parent item. The contents are a comma separated list of items in this container', 'title' => 'Group Children', 'type' => 'finder', 'index'=>'grp_children' },
'zoovy:grp_parent' =>  { 'popular'=>1, 'index'=>'grp_parent', 'hint' => 'When populated indicates this child belongs to a group of items. This field must contain the parent product record', 'max' => 1, 'title' => 'Group Parent', 'type' => 'finder' },
'zoovy:grp_type' =>  { 'popular'=>1, 'options' => [ { 'p' => 'None', 'v' => '' }, { 'p' => 'PARENT', 'v' => 'PARENT' }, { 'p' => 'CHILD', 'v' => 'CHILD' } ], 'hint' => 'When populated indicates group type (PARENT or CHILD)', 'title' => 'Group Type', 'type' => 'select' },
'zoovy:header1' =>  {  'origin' => 'amigaz/LAYOUT.~widepicturerelatedproducts', 'type' => 'text', 'title' => 'Header for Related Products' },
'zoovy:header2' =>  {  'origin' => 'amigaz/LAYOUT.~widepicturerelatedproducts', 'type' => 'text', 'title' => 'Header for Accessories' },
'zoovy:heading1' =>  { 'hint' => 'Heading for Related Products', 'origin' => 'amigaz/LAYOUT.~3image', 'type' => 'text', 'title' => 'Related Prod Heading' },
'zoovy:image1' =>  { 'src' => 'f2ptech:JEEP9', 'type' => 'legacy' },
'zoovy:image1cfg' =>  { 'src' => 'greatlookz:5V1965100', 'type' => 'legacy' },
'zoovy:image2' =>  { 'src' => 'f2ptech:JEEP9', 'type' => 'legacy' },
'zoovy:image3' =>  {  'origin' => 'f2ptech/LAYOUT.~f2p_install_guide', 'type' => 'image', 'title' => 'Image number 3' },
'zoovy:image6' =>  { 'src' => 'sporks:SPORKBOOK', 'type' => 'legacy' },
'zoovy:image7' =>  { 'src' => 'sporks:SPORKBOOK', 'type' => 'legacy' },
'zoovy:image8' =>  { 'src' => 'sporks:SPORKBOOK', 'type' => 'legacy' },
'zoovy:image9' =>  { 'src' => 'sporks:SPORKBOOK', 'type' => 'legacy' },
'zoovy:keywords' =>  { 'popular'=>1, 'index'=>'keywords', 'type' => 'textarea', 'title' => 'Product Keywords', 'rows' => 4, 'cols' => 50 },
'zoovy:linkto' =>  { 'hint' => 'This field is dynamically populated by the syndication engine and contains the link with tracking code to the product', 'type' => 'generated' },
'zoovy:meta_desc' =>  { 'src' => '1stproweddingalbums:AAS-BABY', 'type' => 'textbox', 'name'=>'SEO Meta Description', 'hint'=>'If not set then zoovy:prod_desc will be used' },
'zoovy:meta_description' =>  { 'src' => '4armedforces:0100_D154', 'type' => 'legacy' },
'zoovy:meta_keywords' =>  {  'src' => '4armedforces:0100_D154', 'type' => 'legacy' },
'zoovy:mfg' =>  { 'src' => 'closeoutdude:7653102B', 'type' => 'legacy' },
'zoovy:mfg_basecost' =>  { 'src' => 'sweetwaterscavenger:VH31NNNPRMTBX3437OVM', 'type' => 'legacy' },
'zoovy:mfg_id' =>  { 'src' => 'ejej:MUS75303', 'type' => 'legacy' },
'zoovy:mfg_prodname' =>  { 'src' => 'sweetwaterscavenger:VH31NNNPRMTBX3437OVM', 'type' => 'legacy' },
'zoovy:mfg_sku' =>  { 'src' => 'jmiewald:STARWARS10', 'type' => 'legacy' },
'zoovy:mfgid' =>  { 'src' => 'atozgifts:2915', 'type' => 'legacy' },
'zoovy:mfgsku' =>  { 'hint' => 'This is the product sku that will appear on your website', 'origin' => 'stewarttoys/LAYOUT.~stewarttoysdiscount', 'type' => 'text', 'title' => 'SKU' },
'zoovy:mfgurl' =>  { 'src' => 'nerdgear:NIWLRT', 'type' => 'legacy' },
'zoovy:minitext' =>  { 'hint' => 'This is the custom text block for the top of the page. It should be short so customers can see the product.', 'origin' => 'thechessstore/LAYOUT.~117tcs590image', 'type' => 'text', 'title' => 'Short text for the top of the page' },
'zoovy:model_list' =>  { 'src' => 'ibuystores:NEP-W175-0232', 'type' => 'legacy' },
'zoovy:msrp' =>  {  'origin' => 'brian/WIZARD.~asdf', 'type' => 'textbox', 'title' => 'Retail Price' },
'zoovy:msrp_price' =>  { 'hint' => 'This is the cover price that will appear on your website.', 'origin' => 'thechessstore/LAYOUT.~newbookpage', 'type' => 'text', 'title' => 'Cover Price of Book' },
'zoovy:notes' =>  { 'src' => 'sporks:AUCTIONTEST', 'type' => 'legacy' },
'zoovy:notes_default' =>  { 'src' => '1stproweddingalbums:GIFT100', 'type' => 'legacy' },
'zoovy:notes_display' =>  { 'src' => '1stproweddingalbums:GIFT100', 'type' => 'legacy' },
'zoovy:notes_prompt' =>  { 'src' => '1stproweddingalbums:GIFT100', 'type' => 'legacy' },
'zoovy:on_shelf_qty' =>  { 'src' => 'guitarelectronics:1101401', 'type' => 'legacy' },
'zoovy:order_apiurl' =>  { 'src' => 'ezboston:6301', 'type' => 'legacy' },
'zoovy:other_information' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
'zoovy:other_links' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'text', 'title' => 'TEXT' },
'zoovy:other_products' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
'zoovy:othermodels' =>  {  'origin' => 'charisgames/LAYOUT.~p-innova_discs', 'type' => 'text', 'title' => 'TEXT' },
'zoovy:partnum' =>  { 'src' => 'espressoparts2:F_910', 'type' => 'legacy' },
'zoovy:photo_desc1' =>  {  'origin' => 'f2ptech/LAYOUT.~f2p_install_guide', 'type' => 'text', 'title' => 'Description for photo 1' },
'zoovy:photo_desc2' =>  {  'origin' => 'f2ptech/LAYOUT.~f2p_install_guide', 'type' => 'text', 'title' => 'Description for photo 2' },
'zoovy:pkg_depth' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Depth' },
'zoovy:pkg_exclusive' =>  { 'type' => 'boolean', title=>"Ships Exclusively", hint=>"Use this field to configure rules" },
'zoovy:pkg_height' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Height' },
'zoovy:pkg_length' =>  { 'src' => '4armedforces:2097_JW_BORDER', 'type' => 'legacy' },
'zoovy:pkg_multibox_ignore' =>  { 'title' => 'Ignore this item in multibox shipping', 'type' => 'checkbox' },
'zoovy:pkg_weight' =>  { 'src' => 'discountgunmart:58017', 'type' => 'legacy' },
'zoovy:pkg_width' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Width' },
'zoovy:pogcheckout' =>  { 'src' => '1stproweddingalbums:SA5R7BL12', 'type' => 'legacy' },
'zoovy:pogs_desc' =>  { 'title' => 'Description of options (internal use only)', 'type' => 'hidden' },
'zoovy:post_desc' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },

'zoovy:prod_accessories' =>  { title=>'use zoovy:accessory_products', 'src' => 'highpointscientific:STE-348', 'type' => 'legacy' },
'zoovy:prod_advisory' =>  { 'src' => 'brian:B00005QDW1', 'type' => 'legacy' },
'zoovy:prod_age_group' =>  { 'ns' => 'profile', 'hint' => 'kids and adult are suggested values', 'type' => 'textbox', 'title' => 'Product Age Group' },
'zoovy:prod_arrival_date' =>  {  'origin' => 'hotnsexymama/LAYOUT.~toynk', 'type' => 'textbox', 'title' => 'Expected Arrival Date' },
'zoovy:prod_artist' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Artist', 'type' => 'text' },
'zoovy:prod_asm' =>  { 'index'=>'prod_asm', 'maxlength' => 255, 'title' => 'Product Assembly/Kit skus', 'type' => 'text' },
'pid:assembly' =>  { 'index'=>'assembly', 'maxlength' => 255, 'title' => 'Assembly/Kit skus', 'type' => 'text' },

'sku:upc'=>{ 'sku'=>2, 'type'=>'textbox', 'index'=>'upc', 'SKUDB'=>'UPC' },
'sku:mfgid'=>{ 'sku'=>2, 'type'=>'textbox', 'index'=>'mfgid', 'SKUDB'=>'MFGID' },
'sku:condition' => { 'sku'=>2, 'type'=>'textbox', 'index'=>'condition' },
'sku:inventory' => { 'sku'=>2, 'type'=>'integer', 'index'=>'inventory' },
'sku:assembly' =>  { 'sku'=>2, 'index'=>'assembly', 'maxlength' => 255, 'title' => 'Assembly/Kit skus', 'type' => 'text', 'SKUDB'=>'ASSEMBLY' },
'sku:price' =>  { 'sku'=>2, 'index'=>'price', 'maxlength' => 10, 'title' => 'SKU Price', 'type' => 'currency', 'SKUDB'=>'PRICE' },
'sku:pricetags' => { 'sku'=>2, 'index'=>'pricetags', 'title'=>'Price Tags', 'type'=>'hash:currency', },
'sku:weight' =>  { 'sku'=>1, 'index'=>'weight', 'maxlength' => 255, 'title' => 'SKU Weight', 'type' => 'weight' },
'sku:cost' => { 'sku'=>2, 'type'=>'currency', 'SKUDB'=>'COST' },
'sku:title' =>  { 'sku'=>1, 'index'=>'prod_name', 'maxlength' => 255, 'title' => 'SKU Title (Computed)', 'type' => 'readonly' },
'sku:variation_detail' =>  { 'sku'=>1, 'index'=>'prod_name', 'maxlength' => 255, 'title' => 'SKU Variation Detail (Computed)', 'type' => 'readonly' },

'sku:amz_todo' => { 'sku'=>2, 'type'=>'text', 'SKUDB'=>'AMZ_TODO' },
'sku:amz_asin' => { 'sku'=>2, 'type'=>'text', 'SKUDB'=>'AMZ_ASIN' },
'sku:buy_sku'	=> { 'sku'=>2, 'type'=>'text', },

'sku:dss_strategy' => { 'sku'=>2, 'index'=>'dss_strategy', 'type'=>'text', 'SKUDB'=>'RP_STRATEGY' },
'sku:dss_status' => { 'sku'=>2, 'type'=>'text', 'SKUDB'=>'RP_IS' },
'sku:dss_minprice' => { 'sku'=>2, 'type'=>'icurrency', 'SKUDB'=>'RP_MINPRICE_I' },
'sku:dss_minship' => { 'sku'=>2,  'type'=>'icurrency', 'SKUDB'=>'RP_MINSHIP_I' },
'sku:dss_amzprice' => { 'sku'=>2, 'index'=>'currency', 'type'=>'text', 'SKUDB'=>'RP_AMZPRICE_I' },
'sku:dss_amzship' => { 'sku'=>2, 'index'=>'currency', 'type'=>'text', 'SKUDB'=>'RP_AMZSHIP_I' },
'sku:inv_reorder' => { 'sku'=>3, 'type'=>'text', 'SKUDB'=>'INV_REORDER' },
#'sku:schedules'	=> { 'sku'=>1,	'type'=>'textlist',	'SKUDB'=>'SCHEDULES' },

'zoovy:prod_author' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Author', 'type' => 'text' },
'zoovy:prod_available' =>  {  'origin' => 'flipanese/WIZARD.~flipanese_wizard', 'type' => 'textbox', 'title' => 'Availability' },
'zoovy:prod_available_date' =>  { 'hint' => 'Original Date the product arrived in Stock, ie available', 'type' => 'textbox', 'title' => 'Product Availability Date' },
'zoovy:prod_band' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_bandlength' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_bandwidth' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_banner1' =>  {  'origin' => 'beachmart/LAYOUT.~beachmart_p_jsonpogs_20091005', 'type' => 'image', 'title' => 'Top Banner (767x40)' },
'zoovy:prod_banner1_link' =>  {  'origin' => 'beachmart/LAYOUT.~beachmart_p_jsonpogs_20091005', 'type' => 'textbox', 'title' => 'Link for top banner' },
'zoovy:prod_bgimage1' =>  { 'src' => 'nerdgear:NERD2', 'type' => 'legacy' },
'zoovy:prod_blouse' =>  { 'src' => 'indianselections:AMZNSRK_LAXMI_K_MEEN', 'type' => 'legacy' },
'zoovy:prod_book_author' =>  { 'hint' => 'This is the authors name that will appear on your website.', 'origin' => 'gkworld/LAYOUT.~testproduct2', 'type' => 'text', 'title' => 'Authors Name' },
'zoovy:prod_book_condition' =>  { 'src' => 'digmodern:051505', 'type' => 'legacy' },
'zoovy:prod_book_edition' =>  { 'src' => 'digmodern:051505', 'type' => 'legacy' },
'zoovy:prod_book_format' =>  { 'hint' => 'This is the product format that will appear on your website - hardcover, paperback, etc.', 'origin' => 'gkworld/LAYOUT.~testproduct2', 'type' => 'text', 'title' => 'Format' },
'zoovy:prod_book_isbn' =>  { 'src' => 'bloomindesigns:AREDSEN', 'type' => 'legacy' },
'zoovy:prod_book_jacket' =>  { 'src' => 'digmodern:051505', 'type' => 'legacy' },
'zoovy:prod_book_pages' =>  { 'hint' => 'This is the products number of pages that will appear on your website.', 'origin' => 'gkworld/LAYOUT.~testproduct2', 'type' => 'text', 'title' => 'Number of Pages in the book' },
'zoovy:prod_book_price_guide' =>  {  'origin' => 'crunruh/WIZARD.~oct2008a', 'type' => 'textbox', 'title' => 'Price Guide' },
'zoovy:prod_book_publisher' =>  {  'origin' => 'crunruh/WIZARD.~oct2008a', 'type' => 'textbox', 'title' => 'Publisher' },
'zoovy:prod_bottom' =>  {  'origin' => 'moetown55/LAYOUT.~p-custom_product', 'type' => 'textbox', 'title' => 'Bottom' },
'zoovy:prod_brand' =>  { 'hint' => 'Use only if the brand is different than the manufacturer', 'name' => 'Product Brand', 'product' => 1, 'type' => 'textbox' },
'zoovy:prod_button_addons' =>  { 'src' => 'thegoodtimber:EB_OA270_FULL', 'type' => 'legacy' },
'zoovy:prod_button_assembly' =>  { 'src' => 'thegoodtimber:EB_OA270_FULL', 'type' => 'legacy' },
'zoovy:prod_button_collection' =>  { 'src' => 'thegoodtimber:EB_OA270_FULL', 'type' => 'legacy' },
'zoovy:prod_button_coninfo' =>  { 'src' => 'thegoodtimber:1210FUTONS', 'type' => 'legacy' },
'zoovy:prod_button_shipping' =>  { 'src' => 'thegoodtimber:1210FUTONS', 'type' => 'legacy' },
'zoovy:prod_button_swatch' =>  { 'src' => 'thegoodtimber:PWCM71SOFA', 'type' => 'legacy' },
'zoovy:prod_calendar' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_casepack' =>  { 'src' => 'keybrands:112', 'type' => 'legacy' },
'zoovy:prod_cast' =>  {  'origin' => 'vidbiz/LAYOUT.~jt_test', 'type' => 'text', 'title' => 'Cast' },
'zoovy:prod_ccg' =>  {  'origin' => 'allkindsofstuff/LAYOUT.~p-card', 'type' => 'textbox', 'title' => 'CCG' },
'zoovy:prod_ccg_action' =>  { 'src' => 'sporks:MGC_FE_FARRELS_ZEALO', 'type' => 'legacy' },
'zoovy:prod_ccg_border' =>  { 'src' => 'sporks:MGC_FE_FARRELS_ZEALO', 'type' => 'legacy' },
'zoovy:prod_ccg_color' =>  {  'origin' => 'allkindsofstuff/LAYOUT.~p-card', 'type' => 'textbox', 'title' => 'Card Color' },
'zoovy:prod_ccg_condition' =>  {  'origin' => 'allkindsofstuff/LAYOUT.~p-card', 'type' => 'textbox', 'title' => 'Card Condition' },
'zoovy:prod_ccg_series' =>  { 'src' => 'sporks:MGC_FE_FARRELS_ZEALO', 'type' => 'legacy' },
'zoovy:prod_chaintype' =>  {  'origin' => 'yourdreamizhere/WIZARD.~yourdream', 'type' => 'hidden', 'title' => 'Chain Type' },
'zoovy:prod_chapters' =>  { 'hint' => 'This is the list of chapters.', 'origin' => 'nerdgear/LAYOUT.~p-book_6pic', 'type' => 'text', 'title' => 'Chapters ' },
'zoovy:prod_clasp' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_class' =>  { 'ns' => 'product', 'hint' => '', 'type' => 'textbox', 'title' => 'Product Classification' },
'zoovy:prod_clothing_waist' =>  { 'hint' => 'Please enter the waist size of this item (optional).', 'origin' => 'patti/LAYOUT.~p-1_tall_pic', 'type' => 'textbox', 'title' => 'Product Waist Size' },
'zoovy:prod_color' =>  { 'ns' => 'product', 'hint' => 'Defines product\'s primary color', 'type' => 'textbox', 'title' => 'Product Primary Color' },
'zoovy:prod_colors' =>  {  'origin' => 'modernmini/LAYOUT.~modernmini_colorflow', 'type' => 'image', 'title' => undef },
'zoovy:prod_comment' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Comment' },
'zoovy:prod_condition_note' =>  { 'src' => '2bhip:TS90-00', 'type' => 'legacy' },
'zoovy:prod_condition' =>  { 'popular'=>1, 'index'=>'prod_condition', 'type' => 'textbox', title=>'Product Condition', hint=>'Defaults to "NEW"' },
'zoovy:prod_contents' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
'zoovy:prod_cost' =>  { 'src' => 'jeco:CFZ-028_12', 'type' => 'legacy' },
'zoovy:prod_cost1' =>  { 'src' => 'beltiscool:BD01', 'type' => 'legacy' },
'zoovy:prod_country' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_cover' =>  {  'origin' => 'flipanese/WIZARD.~flipanese_wizard', 'type' => 'textbox', 'title' => 'Cover Artist' },
'zoovy:prod_cpsiawarning' =>  { 'options' => [ { 'p' => '- Please Select -', 'v' => '' }, { 'p' => 'Choking Hazard Balloon', 'v' => 'choking_hazard_balloon' }, { 'p' => 'Choking Hazard contains a marble', 'v' => 'choking_hazard_contains_a_marble' }, { 'p' => 'Choking Hazard contains a small ball', 'v' => 'choking_hazard_contains_small_ball' }, { 'p' => 'Choking Hazard is a marble', 'v' => 'choking_hazard_is_a_marble' }, { 'p' => 'Choking Hazard is a small ball', 'v' => 'choking_hazard_is_a_small_ball' }, { 'p' => 'Choking Hazard small parts', 'v' => 'choking_hazard_small_parts' }, { 'p' => 'No Warning Applicable', 'v' => 'no_warning_applicable' } ], 'title' => 'CPSIA Warning', 'type' => 'select' },
'zoovy:prod_created_gmt' =>  { 'type' => 'constant', },
'zoovy:prod_curtainlength' =>  { 'hint' => 'This is the length of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Curtain Length (optional)' },
'zoovy:prod_curtainlining' =>  { 'src' => 'indianselections:AMZN_CCCRNRBLK', 'type' => 'legacy' },
'zoovy:prod_curtaintieback' =>  { 'src' => 'indianselections:AMZN_CCCRNRBLK', 'type' => 'legacy' },
'zoovy:prod_curtaintiebackk' =>  { 'src' => 'indianselections:CTRDFMCREAM', 'type' => 'legacy' },
'zoovy:prod_curtaintop' =>  { 'hint' => 'This is the Top Style of the curtain(optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Top (optional)' },
'zoovy:prod_curtainwidth' =>  { 'hint' => 'This is the width of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Curtain Width (optional)' },
'zoovy:prod_date_ordered' =>  { 'hint' => 'Date Product was reordered (from Supplier).', 'type' => 'textbox', 'title' => 'Product Date Ordered' },
'zoovy:prod_def' =>  { 'src' => 'proshop:CSTM_FLOW', 'type' => 'legacy' },
'zoovy:prod_depth' =>  { 'src' => '1stproweddingalbums:SA5R7BL12', 'type' => 'legacy' },
'zoovy:prod_desc' =>  { 'popular'=>1, 'index'=>'description', 'title' => 'Product Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 50 },
'zoovy:prod_desc2' =>  {  'origin' => 'f2ptech/LAYOUT.~f2p_install_guide', 'type' => 'text', 'title' => 'Courtesy Credit line' },
'zoovy:prod_desc_detailed' =>  { 'src' => 'cardiacwellness:CONTROL_WEIGHT_LOSS', 'type' => 'legacy' },
'zoovy:prod_desc_short' =>  { 'src' => 'buystonesonline:CG49EB', 'type' => 'legacy' },
'zoovy:prod_description' =>  { 'src' => 'digmodern:T9031905', 'type' => 'legacy' },
'zoovy:prod_designid' =>  { 'type' => 'textbox', 'title' => 'Product Design #' },
'zoovy:prod_detail' =>  { 'popular'=>1, 'index'=>'detail', 'title' => 'Product Detail Description', 'type' => 'textarea', 'rows' => 4, 'cols' => 50 },
'zoovy:prod_detail2' =>  {  'origin' => 'secondact/LAYOUT.~sa_c_dotd_test', 'type' => 'text', 'title' => undef },
'zoovy:prod_detailed' =>  { 'src' => 'affordableproducts:113GLCS94', 'type' => 'legacy' },
'zoovy:prod_details' =>  {  'origin' => 'greatlookz/LAYOUT.~greatlookz_p_magicz_20090624', 'type' => 'text', 'title' => 'Product Detailed Description (optional)' },
'zoovy:prod_dialcolor' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_diameter' =>  { 'src' => 'sweetwaterscavenger:UM26404-1', 'type' => 'legacy' },
'zoovy:prod_dimensions' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Dimensions' },
'zoovy:prod_director' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Director', 'type' => 'text' },
'zoovy:prod_disableprice' =>  { 'hint' => 'Can be used in cases where MAP is defined', 'title' => 'Do not show the price', 'type' => 'checkbox' },
'zoovy:prod_disableprice_text' =>  { 'hint' => 'Can be used in cases where MAP is defined', 'title' => 'Show this text instead of the price', 'type' => 'text', 'size' => 30 },
'zoovy:prod_disclaimer' =>  { 'src' => 'proshop:SPEC_OVERLAY', 'type' => 'legacy' },
'zoovy:prod_e_blouse' =>  { 'src' => 'indianselections:AMZNSRK_LAXMI_K_MEEN', 'type' => 'legacy' },
'zoovy:prod_ean' =>  { 'popular'=>1, 'sku'=>1, 'index'=>'ean', 'hint' => 'EAN (European Article Number is a barcoding standard which is a superset of the original 12-digit UPC system)', 'type' => 'textbox', 'title' => 'Product EAN' },
'zoovy:prod_esize' =>  { 'src' => 'indianselections:AMZN_CCCRNRBLK', 'type' => 'legacy' },
'zoovy:prod_esrb_rating' =>  { 'options' => [ { 'p' => 'RP', 'v' => 'RP' }, { 'p' => 'ED', 'v' => 'ED' }, { 'p' => 'E', 'v' => 'E' }, { 'p' => 'E10', 'v' => 'E10' }, { 'p' => 'T', 'v' => 'T' }, { 'p' => 'M', 'v' => 'M' }, { 'p' => 'AO', 'v' => 'AO' } ], 'title' => 'ESRB Rating', 'type' => 'select' },
'zoovy:prod_estateperiod' =>  {  'origin' => 'yourdreamizhere/WIZARD.~yourdream', 'type' => 'hidden', 'title' => 'Estate Period' },
'zoovy:prod_ext_warranty' =>  { 'src' => 'sporks:OUTFIT', 'type' => 'legacy' },
'zoovy:prod_extra' =>  {  'origin' => 'kcint/WIZARD.~kcint_warlock_extra', 'type' => 'text', 'title' => 'Product Extra Description (not used in all layouts)' },
'zoovy:prod_eyeglass_frametype' =>  { 'options' => [ { 'p' => 'full', 'v' => 'full' }, { 'p' => 'semi', 'v' => 'semi' }, { 'p' => 'rimless', 'v' => 'rimless' } ], 'title' => 'Eyeglass Frame Type', 'type' => 'select' },
'zoovy:prod_eyeglass_type' =>  { 'options' => [ { 'p' => 'sunglasses', 'v' => 'sunglasses' }, { 'p' => 'eyeglasses', 'v' => 'eyeglasses' } ], 'title' => 'Eyeglass Type', 'type' => 'select' },
'zoovy:prod_fabric' =>  { 'hint' => 'This is the fabric of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Fabric (optional)' },
'zoovy:prod_fakeupc' =>  { 'index'=>'fakeupc', 'hint' => 'Creating Fake UPC\'s is probably a bad idea, let us know if you\'ve got another one.', 'title' => 'Fake UPC #', 'type' => 'upc' },
'zoovy:prod_features' =>  { 'popular'=>1, 'index'=>'prod_features', 'hint' => 'Used by Amazon - should contain a bulleted list', 'type' => 'textarea', 'title' => 'Product Features', 'rows' => 4, 'cols' => 50 },
'zoovy:prod_fgid' =>  { 'src' => 'sweetwaterscavenger:UM28546L-FL', 'type' => 'legacy' },
'zoovy:prod_folder' =>  { 'type' => 'management-category', 'title'=>'Product Management Category' },
'zoovy:prod_format' =>  { 'hint' => 'Please enter a the format of this product', 'origin' => 'nerdgear/LAYOUT.~p-dvd_4pic', 'type' => 'textbox', 'title' => 'Format (DVD, VHS, Hardbound, Paperback, CD, Tape, Etc.)' },
'zoovy:prod_frame_material' =>  { 'src' => 'eyeglassliquidators:883475186888', 'type' => 'legacy' },
'zoovy:prod_game_console' =>  { 'src' => 'alternativedvd:TEST', 'type' => 'legacy' },
'zoovy:prod_game_platform' =>  {  'origin' => 'alternativedvd/LAYOUT.~ad_p_3pics', 'type' => 'select', 'title' => 'Platform' },
'zoovy:prod_gender' =>  { 'ns' => 'profile', 'hint' => 'Indicates the gender the product is marketed towards', 'type' => 'textbox', 'title' => 'Product Gender' },
'zoovy:prod_genre' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_golf_manufacturer' =>  {  'origin' => 'brian/WIZARD.series3-gradiate', 'type' => 'textbox', 'title' => 'Product Manufacturer (Optional)' },
'zoovy:prod_hassoftware' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_height' =>  { 'hint' => 'Height of just the product (not the package it\'s shipped in). Used for fulfillment.', 'type' => 'textbox', 'title' => 'Product Height' },
'zoovy:prod_id' =>  { 'hint' => 'Product ID (internal field)', 'type' => 'hidden' },
'zoovy:prod_image1' =>  {  'popular'=>1, 'sku'=>1, 'hint' => 'image1 will also be used as a thumbnail by default', 'title' => 'Product Image 1', 'type' => 'image' },
'zoovy:prod_image2' =>  { 'popular'=>1, 'sku'=>1, 'title' => 'Product Image 2', 'type' => 'image' },
'zoovy:prod_image3' =>  { 'popular'=>1, 'sku'=>1, 'title' => 'Product Image 3', 'type' => 'image' },
'zoovy:prod_image4' =>  { 'popular'=>1, 'sku'=>1, 'title' => 'Product Image 4', 'type' => 'image' },
'zoovy:prod_image5' =>  { 'popular'=>1, 'sku'=>1, 'title' => 'Product Image 5', 'type' => 'image' },
'zoovy:prod_image6' =>  { 'popular'=>1, 'title' => 'Product Image 6', 'type' => 'image' },
'zoovy:prod_image7' =>  { 'popular'=>1, 'title' => 'Product Image 7', 'type' => 'image' },
'zoovy:prod_image8' =>  { 'popular'=>1, 'title' => 'Product Image 8', 'type' => 'image' },
'zoovy:prod_image9' =>  { 'title' => 'Product Image 9', 'type' => 'image' },
'zoovy:prod_image10' =>  { 'title' => 'Product Image 10', 'type' => 'image' },
'zoovy:prod_image11' =>  { 'title' => 'Product Image 11', 'type' => 'image' },
'zoovy:prod_image12' =>  { 'title' => 'Product Image 12', 'type' => 'image' },
'zoovy:prod_image13' =>  { 'title' => 'Product Image 13', 'type' => 'image' },
'zoovy:prod_image14' =>  { 'title' => 'Product Image 14', 'type' => 'image' },
'zoovy:prod_image15' =>  { 'title' => 'Product Image 15', 'type' => 'image' },
'zoovy:prod_image16' =>  { 'title' => 'Product Image 16', 'type' => 'image' },
'zoovy:prod_image17' =>  { 'title' => 'Product Image 17', 'type' => 'image' },
'zoovy:prod_image18' =>  { 'title' => 'Product Image 18', 'type' => 'image' },
'zoovy:prod_image19' =>  { 'title' => 'Product Image 19', 'type' => 'image' },
'zoovy:prod_image20' =>  { 'title' => 'Product Image 20', 'type' => 'image' },
'zoovy:prod_image21' =>  { 'title' => 'Product Image 21', 'type' => 'image' },
'zoovy:prod_image22' =>  { 'title' => 'Product Image 22', 'type' => 'image' },
'zoovy:prod_image23' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 23' },
'zoovy:prod_image24' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 24' },
'zoovy:prod_image25' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 25' },
'zoovy:prod_image26' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 26' },
'zoovy:prod_image27' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 27' },
'zoovy:prod_image28' =>  { 'hint' => 'Please enter a picture for your product.', 'origin' => 'usfreight/LAYOUT.~super_mini_picture', 'type' => 'image', 'title' => 'Image 28' },
'zoovy:prod_image95' =>  { 'title' => 'Product Image 95', 'type' => 'image' },
'zoovy:prod_image96' =>  { 'title' => 'Product Image 96', 'type' => 'image' },
'zoovy:prod_image97' =>  { 'title' => 'Product Image 97', 'type' => 'image' },
'zoovy:prod_image98' =>  { 'title' => 'Product Image 98', 'type' => 'image' },
'zoovy:prod_image99' =>  { 'title' => 'Product Image 99', 'type' => 'image' },
#'zoovy:prod_image99_link' =>  {  'origin' => 'usavem/LAYOUT.~usm_p_5lists', 'type' => 'textbox', 'title' => 'Wide Banner' },
'zoovy:prod_included' =>  { 'src' => 'athruzcloseouts:10504GB', 'type' => 'legacy' },
#'zoovy:prod_info_award1' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
#'zoovy:prod_info_award2' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
#'zoovy:prod_info_award4' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
#'zoovy:prod_info_award6' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
#'zoovy:prod_info_cell' =>  {  'origin' => 'charisgames/LAYOUT.~p-custom_game_1', 'type' => 'html', 'title' => 'HTML' },
'zoovy:prod_install_docs' =>  { 'hint' => 'Paste in the link for the specifications doc and the system will generate the button and link to that doc in a new window.', 'origin' => 'jefatech/LAYOUT.~5pics-no-price', 'type' => 'textbox', 'title' => 'link for INstallation doc' },
'zoovy:prod_instructions' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Care Instructions' },
#'zoovy:prod_int1' =>  { 'hint' => 'Integer(1) for the product', 'title' => 'Product Integer 1', 'type' => 'number', 'size' => 10 },
#'zoovy:prod_int2' =>  { 'hint' => 'Integer(2) for the product', 'title' => 'Product Integer 2', 'type' => 'number', 'size' => 10 },
#'zoovy:prod_int3' =>  { 'hint' => 'Integer(3) for the product', 'title' => 'Product Integer 3', 'type' => 'number', 'size' => 10 },
'zoovy:prod_inv' =>  { 'src' => 'rcm1:BLAC228', 'type' => 'legacy' },
'zoovy:prod_inv_availability' =>  {  'origin' => 'yogaaccessories/LAYOUT.~yac_p_colorchooser', 'type' => 'textbox', 'title' => 'Availability' },
'zoovy:prod_inv_message' =>  {  'origin' => 'hotnsexymama/LAYOUT.~toynk', 'type' => 'textbox', 'title' => 'Inventory Message' },
'zoovy:prod_invmessage' =>  { 'hint' => 'Please enter a inventory display message', 'origin' => 'sportstop/LAYOUT.~p-custom', 'type' => 'textbox', 'title' => 'Invetory Display Message' },
'zoovy:prod_is' =>  { 'type' => 'constant', },
'zoovy:prod_is_tags' =>  { 'type' => 'hidden' },
'zoovy:prod_isbn' =>  { 'popular'=>1, 'sku'=>1, 'index'=>'isbn', 'maxlength' => 13, 'hint' => 'Used to describe Media.', 'title' => 'ISBN', 'type' => 'text', 'size' => 13 },
'zoovy:prod_itemno' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Item #' },
'zoovy:prod_keywords' =>  { 'popular'=>1, 'src' => 'camdenbar:6X6CL', 'type' => 'legacy' },
'zoovy:prod_label' =>  { 'hint' => 'Please enter a the label of this album', 'origin' => 'nerdgear/LAYOUT.~p-cd_2pic', 'type' => 'textbox', 'title' => 'Label' },
'zoovy:prod_language' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_lccn' =>  { 'src' => 'digmodern:051505', 'type' => 'legacy' },
'zoovy:prod_lead_time' =>  { 'src' => 'indianselections:HCMSA_M-RP-158', 'type' => 'legacy' },
'zoovy:prod_leadtime' =>  { 'hint' => 'This is the lead time of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Product Lead Time (optional)' },
'zoovy:prod_length' =>  { 'hint' => 'length of just the product (not the package it\'s shipped in). Used for fulfillment.', 'type' => 'textbox', 'title' => 'Product Length' },
'zoovy:prod_limited_availability' =>  {  'origin' => 'usavem/LAYOUT.~usm_p_5lists', 'type' => 'checkbox', 'title' => 'Show retired banner' },
'zoovy:prod_lining' =>  { 'hint' => 'This is the lining of the product (optional)', 'origin' => 'indianselections/LAYOUT.~p-final_sari', 'type' => 'textbox', 'title' => 'Product Lining (optional)' },
'zoovy:prod_link1' =>  { 'maxlength' => 200, 'hint' => 'url to another page about the product e.g. PDF manual', 'type' => 'textbox', 'title' => 'Product Link URL 1', 'size' => 60 },
'zoovy:prod_link2' =>  { 'maxlength' => 200, 'hint' => 'url to another page about the product e.g. PDF manual', 'type' => 'textbox', 'title' => 'Product Link URL 2', 'size' => 60 },
'zoovy:prod_link3' =>  { 'maxlength' => 200, 'hint' => 'url to another page about the product e.g. PDF manual', 'type' => 'textbox', 'title' => 'Product Link URL 3', 'size' => 60 },
'zoovy:prod_link4' =>  { 'maxlength' => 200, 'hint' => 'url to another page about the product e.g. PDF manual', 'type' => 'textbox', 'title' => 'Product Link URL 4', 'size' => 60 },
'zoovy:prod_link5' =>  { 'maxlength' => 200, 'hint' => 'url to another page about the product e.g. PDF manual', 'type' => 'textbox', 'title' => 'Product Link URL 5', 'size' => 60 },
'zoovy:prod_link6' =>  {  'origin' => 'ibuystores/LAYOUT.~pf_p_partlocator', 'type' => 'textbox', 'title' => 'Banner 1 link' },
'zoovy:prod_link7' =>  {  'origin' => 'ibuystores/LAYOUT.~pf_p_partlocator', 'type' => 'textbox', 'title' => 'Banner 2 link' },
'zoovy:prod_list1' =>  { 'hint' => 'Used by Design Team', 'type' => 'finder', 'title' => 'Custom Product List 1' },
'zoovy:prod_list1_style' =>  {  'origin' => 'eyeglassliquidators/LAYOUT.~test', 'type' => 'prodlist', 'title' => 'Product List: related items (colors)' },
'zoovy:prod_list1_title' =>  { 'hint' => '', 'title' => 'Title for Product List 1', 'type' => 'text', 'size' => 20 },
'zoovy:prod_list2' =>  { 'hint' => 'Used by Design Team', 'type' => 'finder', 'title' => 'Custom Product List 2' },
'zoovy:prod_list2_title' =>  { 'hint' => '', 'title' => 'Title for Product List 2', 'type' => 'text', 'size' => 20 },
'zoovy:prod_list3' =>  { 'hint' => 'Used by Design Team', 'type' => 'finder', 'title' => 'Custom Product List 3' },
'zoovy:prod_list3_title' =>  { 'hint' => '', 'title' => 'Title for Product List 3', 'type' => 'text', 'size' => 20 },
'zoovy:prod_list4' =>  { 'hint' => 'Used by Design Team', 'type' => 'finder', 'title' => 'Custom Product List 4' },
'zoovy:prod_list4_title' =>  { 'hint' => '', 'title' => 'Title for Product List 4', 'type' => 'text', 'size' => 20 },
'zoovy:prod_list5' =>  { 'hint' => 'Used by Design Team', 'type' => 'finder', 'title' => 'Custom Product List 5' },
'zoovy:prod_list5_title' =>  { 'hint' => '', 'title' => 'Title for Product List 5', 'type' => 'text', 'size' => 20 },
'zoovy:prod_list_style' =>  { 'src' => 'atozgifts:LSK804', 'type' => 'legacy' },
'zoovy:prod_listhead1' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 1 Header' },
'zoovy:prod_listhead2' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 2 Header' },
'zoovy:prod_listhead3' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 3 Header' },
'zoovy:prod_listhead4' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 4 Header' },
'zoovy:prod_listhead5' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 5 Header' },
'zoovy:prod_listhead6' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 6 Header' },
'zoovy:prod_listhead7' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Product List 7 Header' },
'zoovy:prod_location' =>  { 'src' => 'capg:E253-00', 'type' => 'legacy' },
'zoovy:prod_map' =>  {  'origin' => 'aaavacs/LAYOUT.~prod_map', 'type' => 'checkbox', 'title' => 'MAP Enable/Disable' },
'zoovy:prod_map_hideprice' =>  {  'origin' => 'costlow/LAYOUT.~cl_product', 'type' => 'checkbox', 'title' => 'MAP: Hide Price' },
'zoovy:prod_mapprice' =>  { 'format' => 'currency', 'hint' => 'Defines the "Minimum Advertised Price" as necessary', 'title' => 'MAP Price', 'type' => 'number', 'size' => 20 },
'zoovy:prod_material' =>  { 'src' => 'toynk:ICN-50009ST-C', 'type' => 'legacy' },
'zoovy:prod_measurements' =>  { 'hint' => 'Please enter the measurements of this item (optional).', 'origin' => 'patti/LAYOUT.~p-1_tall_pic', 'type' => 'textbox', 'title' => 'Product Measurements' },
'zoovy:prod_meta_desc' =>  { 'src' => 'ibuystores:MON1278', 'type' => 'legacy' },
'zoovy:prod_meta_desc1' =>  { 'title' => 'Alt Meta Description #1', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_meta_desc2' =>  { 'title' => 'Alt Meta Description #2', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_meta_desc3' =>  { 'title' => 'Alt Meta Description #3', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_meta_desc4' =>  { 'title' => 'Alt Meta Description #4', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_meta_desc5' =>  { 'title' => 'Alt Meta Description #5', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_metal' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
#'zoovy:prod_mf' =>  {  'origin' => 'flipanese/WIZARD.~flipanese_wizard', 'type' => 'textbox', 'title' => 'Manufacturer/Publisher' },
'zoovy:prod_mfg' =>  { 'popular'=>1, 'index'=>'prod_mfg', 'type' => 'textbox', 'title' => 'Product Manufacturer' },
'zoovy:prod_mfg_link' =>  {  'origin' => 'usavem/LAYOUT.~usm_p_5lists', 'type' => 'textbox', 'title' => 'Manufacturer cat safe id (ex: dolls_by_maker.adora_limited_edition_dolls)' },
'zoovy:prod_mfgid' =>  { 'popular'=>1, 'index'=>'prod_mfgid', 'type' => 'textbox', 'sku'=>1, 'title' => 'Product Manufacturer ID' },
# 'zoovy:prod_mfgid2' =>  { 'src' => 'sweetwaterscavenger:UM24002AF-T', 'type' => 'legacy' },
# 'zoovy:prod_mfgno' =>  { 'src' => 'ezboston:6301', 'type' => 'legacy' },
# 'zoovy:prod_mfgurl' =>  { 'src' => 'ezboston:PCI-9G8EXL-BLUE', 'type' => 'legacy' },
# 'zoovy:prod_midtext' =>  { 'src' => 'proshop:CSTM_EBAY', 'type' => 'legacy' },
# 'zoovy:prod_midtext2' =>  { 'src' => 'proshop:PACK_STANDARD', 'type' => 'legacy' },
'zoovy:prod_model' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Model' },
'zoovy:prod_modelid' =>  { 'type' => 'textbox', 'title' => 'Product Model #' },
'zoovy:prod_modified_gmt' =>  { 'type' => 'hidden', 'title'=>'Computed field used to store the last time the product was modified.' },
'zoovy:prod_movement' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_mpa_rating' =>  { 'options' => [ { 'p' => '-', 'v' => '-' }, { 'p' => 'G', 'v' => 'G' }, { 'p' => 'PG', 'v' => 'PG' }, { 'p' => 'PG-13', 'v' => 'PG-13' }, { 'p' => 'R', 'v' => 'R' }, { 'p' => 'NC-17', 'v' => 'NC-17' } ], 'title' => 'MPA Rating', 'type' => 'select' },
# 'zoovy:prod_mpgid' =>  { 'src' => 'indianselections:AB01', 'type' => 'legacy' },
'zoovy:prod_mpn' =>  { 'src' => 'sporks:4PRONGCLASSIC', 'type' => 'legacy' },
'zoovy:prod_mrsp' =>  { 'src' => '888knivesrus:CS29TLCH', 'type' => 'legacy' },
# 'zoovy:prod_msg' =>  { 'src' => 'orangeonions:759600', 'type' => 'legacy' },
'zoovy:prod_msrp' =>  { 'hint' => 'This is the msrp that will appear crossed out on your website. Saved to product:zoovy:prod_msrp', 'origin' => 'brian/LAYOUT.133', 'type' => 'text', 'title' => ' MSRP' },
'zoovy:prod_music_artist' =>  { 'src' => 'colocustommetal:RIDE2', 'type' => 'legacy' },
'zoovy:prod_music_format' =>  { 'src' => 'colocustommetal:RIDE2', 'type' => 'legacy' },
'zoovy:prod_music_releasedate' =>  { 'src' => 'colocustommetal:RIDE2', 'type' => 'legacy' },
'zoovy:prod_name' =>  { 'popular'=>1, 'index'=>'prod_name', 'maxlength' => 200, 'title' => 'Product Title', 'type' => 'text', 'size' => 60 },
#'zoovy:prod_name_color' =>  { 'src' => 'brian:BEC', 'type' => 'legacy' },
#'zoovy:prod_name_orig' =>  { 'src' => 'barefoottess:8020-CHARLIE-BRNA00A', 'type' => 'legacy' },
#'zoovy:prod_nextcopy' =>  { 'hint' => 'This is the body copy that will be used for the second block of usage instructions.', 'origin' => 'maakenterprises/LAYOUT.~p-maak_product', 'type' => 'text', 'title' => 'Second Instructions Body Copy (shared)' },
#'zoovy:prod_nexthead' =>  { 'hint' => 'This is the headline that will appear for the second block of usage instructions.', 'origin' => 'maakenterprises/LAYOUT.~p-maak_product', 'type' => 'textbox', 'title' => 'Second Instructions Headline (shared)' },
'zoovy:prod_notes' =>  { 'hint' => 'Internal Product Notes (re: inventory/shipping/ordering).', 'type' => 'textarea', 'title' => 'Product Notes', 'rows' => 4, 'cols' => 50 },
'zoovy:prod_num' =>  { 'src' => 'kcint:60-93-268-06', 'type' => 'legacy' },
'zoovy:prod_num_units' =>  { 'minval' => 1, 'hint' => 'Enter the total units shipped within a given product (pack).', 'max' => 1000, 'type' => 'number', 'title' => 'Number of units per pack' },
'zoovy:prod_number' =>  { 'hint' => 'Please enter a the screen format of this movie', 'origin' => 'nerdgear/LAYOUT.~p-dvd_4pic', 'type' => 'textbox', 'title' => 'Number of disks/tapes' },
'zoovy:prod_oem' =>  {  'origin' => 'kcint/LAYOUT.~product', 'type' => 'textbox', 'title' => 'OEM Replacement Part #' },
'zoovy:prod_offer' =>  { 'hint' => 'Add additional product information here, such as Free Shipping or 10% Off.', 'origin' => 'maakenterprises/LAYOUT.~p-maak_product', 'type' => 'textbox', 'title' => 'Extra offer information (shared)' },
'zoovy:prod_optionsku' =>  { 'hint' => 'This is the product description that will appear on your website.', 'origin' => 'jefatech/LAYOUT.~p-5pics-options-nobuybutton', 'type' => 'text', 'title' => 'Product Option Buy Buttons' },
'zoovy:prod_originalyear' =>  { 'hint' => 'Please enter a the year the movie was released', 'origin' => 'nerdgear/LAYOUT.~p-vhs_6pic', 'type' => 'textbox', 'title' => 'Year Released' },
'zoovy:prod_oversized' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_oz' =>  { 'hint' => 'This is the product Size (oz) that will appear on your website.', 'origin' => 'keybrands/LAYOUT.~p-custom', 'type' => 'textbox', 'title' => ' Size (oz)' },
'zoovy:prod_packagedeal' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'prodlist', 'title' => 'Product List: Package Deal' },
'zoovy:prod_packagedeal_list' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Package Deal Skus - max 3 (Comma Separated List)' },
'zoovy:prod_pages' =>  { 'maxlength' => 5, 'hint' => 'Used to describe Media (this attribute should be a number!)', 'title' => 'Pages', 'type' => 'text', 'size' => 5 },
'zoovy:prod_partnum' =>  { 'hint' => 'Use only if there is an additional part number which is different than the manufacturers product id.', 'name' => 'Product Part Number', 'product' => 1, 'type' => 'textbox' },
'zoovy:prod_price' =>  { 'src' => 'barefoottess:FP-KK-ROSE', 'type' => 'legacy' },
'zoovy:prod_primary_category' =>  {  'origin' => 'alternativedvd/LAYOUT.~ad_p_3pics', 'type' => 'textbox', 'title' => 'Primary Category' },
'zoovy:prod_private_note' =>  { 'title' => 'Private Notes about this product (not displayed on site)', 'type' => 'textarea', 'rows' => 4, 'cols' => 70 },
'zoovy:prod_prodlist' =>  {  'origin' => 'beautystore/LAYOUT.~beautystore_product', 'type' => 'finder', 'title' => 'Product List' },
'zoovy:prod_prodlist2' =>  {  'origin' => 'elvistech/LAYOUT.~et_home', 'type' => 'finder', 'title' => 'Product List #2' },
'zoovy:prod_prodlist2_style' =>  {  'origin' => 'mynicolita/LAYOUT.~mn_p_upsell', 'type' => 'prodlist', 'title' => 'Product List: More Matching Pieces' },
'zoovy:prod_prodlist6_style' =>  {  'origin' => 'bamtar/LAYOUT.~bamtar_p_clicktoshopstores_20100209', 'type' => 'prodlist', 'title' => 'Product List: Recently Viewed Items' },
'zoovy:prod_prodlist7_style' =>  {  'origin' => 'bamtar/LAYOUT.~bamtar_p_clicktoshopstores_20100209', 'type' => 'prodlist', 'title' => 'Product List: Items from same categories' },
'zoovy:prod_prodlist_style' =>  { 'src' => 'geoffhavens:TW19C1', 'type' => 'legacy' },
'zoovy:prod_prodlist_style1' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 1' },
'zoovy:prod_prodlist_style2' =>  {  'origin' => 'brian/LAYOUT.p-20060921', 'type' => 'prodlist', 'title' => 'Product List - Accessories' },
'zoovy:prod_prodlist_style3' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 3' },
'zoovy:prod_prodlist_style4' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 4' },
'zoovy:prod_prodlist_style5' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 5' },
'zoovy:prod_prodlist_style6' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 6' },
'zoovy:prod_prodlist_style7' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'prodlist', 'title' => 'Product List 7' },
'zoovy:prod_producer' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Producer', 'type' => 'text' },
'zoovy:prod_profile' =>  { 'hint' => 'If the item ships via ground, second day and next day, then you should check this box. Otherwise, leave it unchecked for big ticket item shipping. (info for import: 0 - big item, 1 = small item. Field = product:zoovy:prod_profile. Any value besides 0 or 1 may break shipping)', 'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'select', 'title' => 'Product Shipping Profile' },
'zoovy:prod_promoclass' =>  { 'title' => 'Product Promotion Class', 'type' => 'text', 'index'=>'promoclass' },
'zoovy:prod_promotxt' =>  { 'src' => 'andreasinc:110100', 'type' => 'legacy' },
'zoovy:prod_publisher' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Publisher', 'type' => 'text' },
'zoovy:prod_publishyear' =>  { 'hint' => 'Please enter a the year the movie was released', 'origin' => 'nerdgear/LAYOUT.~p-book_6pic', 'type' => 'textbox', 'title' => 'Year Released' },
'zoovy:prod_qty' =>  { 'src' => 'guitarelectronics:1101401', 'type' => 'legacy' },
'zoovy:prod_qty_ordered' =>  { 'hint' => 'Quantity of Product that was reordered (from Supplier)', 'type' => 'textbox', 'title' => 'Product Quantity Ordered' },
'zoovy:prod_rank' =>  { 'hint' => 'a merchant set number that represents how popular a product is (more is better)', 'type' => 'textbox', 'title' => 'Product Rank' },
'zoovy:prod_rating' =>  { 'hint' => 'This is the Rating the movie was given by the MPAA.', 'origin' => 'vicegripped/LAYOUT.~p-video102', 'type' => 'text', 'title' => 'MPAA Rating' },
'zoovy:prod_rec_ages' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Recommended Ages: ' },
'zoovy:prod_redir' =>  { 'src' => 'mcdc:BANNER4', 'type' => 'legacy' },
'zoovy:prod_redirect' =>  { 'src' => 'mcdc:BANNER4', 'type' => 'legacy' },
'zoovy:prod_region' =>  { 'src' => 'brian:B00005QDW1', 'type' => 'legacy' },
'zoovy:prod_related' =>  { 'src' => 'amigaz:A11N', 'type' => 'legacy' },
'zoovy:prod_release' =>  {  'origin' => 'flipanese/WIZARD.~flipanese_wizard', 'type' => 'textbox', 'title' => 'Release Date' },
'zoovy:prod_release year' =>  { 'hint' => 'Please enter a the year the movie was released', 'origin' => 'nerdgear/LAYOUT.~p-vhs_6pic', 'type' => 'textbox', 'title' => 'Year Released on Video/DVD' },
'zoovy:prod_release_date' =>  {  'origin' => 'alternativedvd/LAYOUT.~ad_p_3pics', 'type' => 'textbox', 'title' => 'Release Date (Format: MM/DD/YYYY)' },
'zoovy:prod_releasedate' =>  { 'hint' => 'This is the date upon which the movie was released', 'origin' => 'vicegripped/LAYOUT.~p-music111', 'type' => 'text', 'title' => 'Date the movie was released' },
'zoovy:prod_releaseyear' =>  { 'src' => 'brian:THIHSI', 'type' => 'legacy' },
'zoovy:prod_requirements' =>  { 'src' => 'closeoutdude:7653102B', 'type' => 'legacy' },
'zoovy:prod_rev' =>  { 'type' => 'hidden', 'title'=>'Zoovy Internal Version # for Product Data Storage - DO NOT UPDATE' },
'zoovy:prod_review' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_reviews' =>  {  'origin' => 'brian/LAYOUT.p-20060921', 'type' => 'reviews', 'title' => undef },
'zoovy:prod_rss_title' =>  { 'src' => '4my3boyz:WHIMFAIRIESHIDING', 'type' => 'legacy' },
'zoovy:prod_runtime' =>  { 'hint' => 'Please enter the approximate running time of this movie.', 'origin' => 'nerdgear/LAYOUT.~p-vhs_6pic', 'type' => 'textbox', 'title' => 'Approx. running time' },
'zoovy:prod_sale_ends' =>  {  'origin' => 'discountgunmart/LAYOUT.~dgm_p_3lists', 'type' => 'textbox', 'title' => 'Sale Expiration (should be formatted as YYYY/MM/DD)' },
'zoovy:prod_salesrank' =>  { 'index'=>'salesrank', 'hint' => 'a user defined field, typically used for date (formatted as YYYYMMDD) for sorting purposes on the storefront. value MUST be a number.', 'origin' => 'expeditionimports/LAYOUT.~prod_5pics', 'type' => 'textbox', 'title' => 'Sales Rank (uses zoovy:prod_salesrank)' },
'zoovy:prod_sarilength' =>  { 'src' => 'indianselections:AMZNSRK_LAXMI_K_MEEN', 'type' => 'legacy' },
'zoovy:prod_sariwidth' =>  { 'hint' => 'This is the width of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Sari Width (optional)' },
'zoovy:prod_screen' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_sdesc' =>  { 'hint' => 'This is the synopsis of the movie.', 'origin' => 'nerdgear/LAYOUT.~p-vhs_4pic', 'type' => 'text', 'title' => 'Synopsis (shared)' },
'zoovy:prod_sell' =>  { 'src' => 'finale:3GLFE098', 'type' => 'legacy' },
'zoovy:prod_seo' =>  { 'src' => 'yourdreamizhere:97BB331534', 'type' => 'legacy' },
'zoovy:prod_seo_priority' =>  { 'hint' => 'A two digit precision number between 0.01 and 1.00', 'title' => 'Sitemap Priority', 'type' => 'number' },
'zoovy:prod_seo_title' =>  { 'maxlength'=>1024, 'type' => 'text', 'title'=>'SEO Meta Title', 'size'=>80 },
'zoovy:prod_seo_title1' =>  { 'maxlength' => 1024, 'title' => 'Alt SEO Meta Title #1', 'type' => 'text', 'size' => 80 },
'zoovy:prod_seo_title2' =>  { 'maxlength' => 1024, 'title' => 'Alt SEO Meta Title #2', 'type' => 'text', 'size' => 80 },
'zoovy:prod_seo_title3' =>  { 'maxlength' => 1024, 'title' => 'Alt SEO Meta Title #3', 'type' => 'text', 'size' => 80 },
'zoovy:prod_seo_title4' =>  { 'maxlength' => 1024, 'title' => 'Alt SEO Meta Title #4', 'type' => 'text', 'size' => 80 },
'zoovy:prod_seo_title5' =>  { 'maxlength' => 1024, 'title' => 'Alt SEO Meta Title #5', 'type' => 'text', 'size' => 80 },
'zoovy:prod_ship_cost' =>  { 'src' => 'sporks:AUCTIONTEST', 'type' => 'legacy' },
'zoovy:prod_ship_message' =>  { 'hint' => 'Please enter the shipping message', 'origin' => 'satin/LAYOUT.~p-custom_tallpic', 'type' => 'textbox', 'title' => 'Shipping Message' },
'zoovy:prod_ship_note' =>  { 'src' => 'outdoorgearco:08239', 'type' => 'legacy' },
'zoovy:prod_shipcontents' =>  { 'src' => 'closeoutdude:7653102B', 'type' => 'legacy' },
'zoovy:prod_shipgraphic' =>  {  'origin' => 'gkworld/LAYOUT.~p-', 'type' => 'select', 'title' => 'Shipping Graphic' },
'zoovy:prod_shiptext' =>  {  'origin' => 'discountgunmart/LAYOUT.~dgm_p_3lists', 'type' => 'textbox', 'title' => 'Shipping Text (will ship in X days)' },
'zoovy:prod_short_desc' =>  { 'src' => 'jhunt:03236', 'type' => 'legacy' },
'zoovy:prod_shortdesc' =>  {  'origin' => 'tooltaker/LAYOUT.~tt_p_fields', 'type' => 'text', 'title' => 'Short Product Description (for use in lists and at top of product page)' },
'zoovy:prod_show_msrp' =>  {  'origin' => 'usavem/LAYOUT.~usm_p_5lists', 'type' => 'checkbox', 'title' => 'Show MSRP/Savings' },
'zoovy:prod_show_no_price' =>  {  'origin' => 'zephyrsports/LAYOUT.~item_zephyr_sports_standard', 'type' => 'textbox', 'title' => 'Dont show price Text' },
'zoovy:prod_showquantity_prompt' =>  { 'type' => 'textbox', 'title' => 'Prompt for the quantity box' },
'zoovy:prod_size' =>  { 'ns' => 'profile', 'hint' => 'Used with grouped products or where products are only avail in one size.', 'type' => 'textbox', 'title' => 'Product Size' },
'zoovy:prod_sizecolor' =>  { 'hint' => 'Please enter the size/color of this item (optional - Do NOT use this if you have specified the stand alone color and/or size for this product).', 'origin' => 'patti/LAYOUT.~p-1_tall_pic', 'type' => 'textbox', 'title' => 'Product Size and Color' },
'zoovy:prod_sizetip' =>  { 'ns' => 'profile', 'hint' => 'Used when more information is needed about a product size.', 'type' => 'textbox', 'title' => 'Product Size Tip' },
'zoovy:prod_sizing' =>  {  'origin' => 'pinkandblue/LAYOUT.~custom_product', 'type' => 'textbox', 'title' => 'Sizing' },
'zoovy:prod_sizingchart_link' =>  { 'hint' => 'paste in the link to the sizing chart', 'origin' => 'satin/LAYOUT.~p-custom_tallpic', 'type' => 'textbox', 'title' => 'Link to Sizing Chart' },
'zoovy:prod_skintype' =>  {  'origin' => 'pure4you/LAYOUT.~p4u_p_5lists', 'type' => 'textbox', 'title' => 'Skin Type' },
'zoovy:prod_sku' =>  { 'src' => 'sweetwaterscavenger:UM13607', 'type' => 'legacy' },
'zoovy:prod_solutions' =>  {  'origin' => 'firefoxtechnologies/LAYOUT.~firefox_product', 'type' => 'textbox', 'title' => 'Solutions' },
'zoovy:prod_sound' =>  { 'src' => 'brian:ABC124', 'type' => 'legacy' },
'zoovy:prod_sound_ac3' =>  { 'src' => 'brian:THIHSI', 'type' => 'legacy' },
'zoovy:prod_sound_cx' =>  { 'src' => 'brian:THIHSI', 'type' => 'legacy' },
'zoovy:prod_sound_dolby' =>  { 'src' => 'brian:THIHSI', 'type' => 'legacy' },
'zoovy:prod_sound_dts' =>  { 'src' => 'brian:THIHSI', 'type' => 'legacy' },
'zoovy:prod_sound_stereo' =>  {  'origin' => 'sporks/WIZARD.~poop', 'type' => 'checkbox', 'title' => 'Sound: Stereo Encoding' },
'zoovy:prod_sound_summary' =>  { 'src' => 'hotnsexymama:025192307522', 'type' => 'legacy' },
'zoovy:prod_sound_thx' =>  { 'src' => 'hotnsexymama:025192307522', 'type' => 'legacy' },
'zoovy:prod_specifications' =>  { 'src' => 'batterup:W0001', 'type' => 'legacy' },
'zoovy:prod_specs' =>  { 'hint' => 'Paste in the link for the specifications doc and the system will generate the button and link to that doc in a new window.', 'origin' => 'jefatech/LAYOUT.~5pics-no-price', 'type' => 'textbox', 'title' => 'link for specifications doc' },
'zoovy:prod_src' =>  { 'src' => 'greatlookz:1GSWCH', 'type' => 'legacy' },
'zoovy:prod_stamp' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_starring' =>  {  'origin' => 'vidbiz/LAYOUT.~jt_test', 'type' => 'text', 'title' => 'Starring' },
'zoovy:prod_stars' =>  { 'hint' => 'This is a comma seperated list of the stars in the movie', 'origin' => 'vicegripped/LAYOUT.~p-video102', 'type' => 'text', 'title' => 'Stars in the movie' },
'zoovy:prod_studio' =>  { 'hint' => 'Please enter a the writer of this product', 'origin' => 'vidbiz/LAYOUT.~p-custom', 'type' => 'textbox', 'title' => 'Studio: ' },
'zoovy:prod_styles' =>  {  'origin' => 'thebabycompany/LAYOUT.~product', 'type' => 'textbox', 'title' => 'Styles:' },
'zoovy:prod_subhead' =>  { 'hint' => 'This is the optional subheading. This should be very short. 1 line max.', 'origin' => 'patti/LAYOUT.~p-1_tall_pic', 'type' => 'textbox', 'title' => 'Subheading.' },
'zoovy:prod_supplier' =>  { 'title' => 'Product Supplier (must be a valid SUPPLY CHAIN code)', 'type' => 'text', 'size' => 10 },
#'zoovy:prod_supplierid' =>  { 'title' => 'Product Supplier ID/SKU', 'type' => 'text', 'size' => 20, 'index'=>'prod_supplierid' },
'zoovy:prod_synopsis' =>  { 'hint' => 'This is the synopsis of the movie.', 'origin' => 'nerdgear/LAYOUT.~p-vhs_6pic', 'type' => 'text', 'title' => 'Synopsis (shared)' },
'zoovy:prod_tags' =>  { 'hint' => 'a space or comma separated list of words which will be used to search for this product', 'type' => 'textarea', 'title' => 'Product Tags' },
'zoovy:prod_taxable' =>  { 'src' => 'brian:FOOBO', 'type' => 'legacy' },
'zoovy:prod_text2' =>  { 'src' => 'laartwork:INDY_EBAY', 'type' => 'legacy' },
'zoovy:prod_text3' =>  {  'origin' => 'laartwork/LAYOUT.~la_product_page', 'type' => 'text', 'title' => undef },
'zoovy:prod_text4' =>  {  'origin' => 'laartwork/LAYOUT.~la_product_page', 'type' => 'text', 'title' => undef },
'zoovy:prod_text5' =>  {  'origin' => 'laartwork/LAYOUT.~la_product_page', 'type' => 'text', 'title' => undef },
'zoovy:prod_text6' =>  { 'src' => 'laartwork:V-ARAKS-CIGAR_EBY', 'type' => 'legacy' },
'zoovy:prod_textcolor1' =>  { 'src' => 'nerdgear:MINT1', 'type' => 'legacy' },
'zoovy:prod_theme' =>  { 'src' => 'redford:MG437011', 'type' => 'legacy' },
'zoovy:prod_thickness' =>  { 'src' => 'sporks:WATCH', 'type' => 'legacy' },
'zoovy:prod_thumb' =>  { 'hint' => 'only set this if you plan to use a different image for your product thumbnail', 'title' => 'Product Image Thumbnail', 'type' => 'image' },
'zoovy:prod_thumb_alt' =>  { 'src' => 'kidsafeinc:07160', 'type' => 'legacy' },
'zoovy:prod_tieback' =>  { 'src' => 'indianselections:AMZN_CCCRNRBLK', 'type' => 'legacy' },
'zoovy:prod_tiebacks' =>  { 'hint' => 'This is the tiebacks of the product (optional)', 'origin' => 'indianselections/LAYOUT.~p-final_sari', 'type' => 'textbox', 'title' => 'Product Tiebacks (optional)' },
'zoovy:prod_title' =>  { 'src' => 'beautymart:ABA_BAS_COND_33', 'type' => 'legacy' },
'zoovy:prod_top' =>  {  'origin' => 'indianselections/LAYOUT.~p-final_sari', 'type' => 'textbox', 'title' => 'Top (optional)' },
'zoovy:prod_tracklist' =>  { 'src' => 'brian:B00005QDW1', 'type' => 'legacy' },
'zoovy:prod_tracks' =>  { 'hint' => 'Please enter a the number of tracks on this album', 'origin' => 'nerdgear/LAYOUT.~p-cd_2pic', 'type' => 'textbox', 'title' => 'Tracks' },
'zoovy:prod_type' =>  {  'origin' => 'flipanese/WIZARD.~flipanese_wizard', 'type' => 'textbox', 'title' => 'Type' },
'zoovy:prod_ugenre' =>  { 'hint' => 'Used in the old media package. prod_genre was left alone so we could add something more structured later.', 'title' => 'Unstructured Genre', 'type' => 'text' },
'zoovy:prod_unit' =>  { 'hint' => 'This is the Unit of the product (optional)', 'origin' => 'patti/LAYOUT.~p-final_curtains', 'type' => 'textbox', 'title' => 'Unit (optional)' },
'zoovy:prod_upc' =>  { 'index'=>'upc', 'hint' => 'UPC (Universal Product Code)', 'sku'=>1, 'type' => 'textbox', 'title' => 'Product UPC' },
'zoovy:prod_ups' =>  { 'src' => 'mandwsales:7391', 'type' => 'legacy' },
'zoovy:prod_url_mfg_rebate' =>  { 'src' => 'tooltaker:DC9PAKRA', 'type' => 'legacy' },
'zoovy:prod_url_pdf' =>  {  'origin' => 'wildemats/LAYOUT.~wildemats_p_tabbed_20090719', 'type' => 'textbox', 'title' => 'Download PDF URL (just the url)' },
'zoovy:prod_url_redir' =>  {  'origin' => 'ahlersgifts/LAYOUT.~ag_product_redirect', 'type' => 'textbox', 'title' => 'URL of page that is linked to' },
'zoovy:prod_url_sizechart' =>  {  'origin' => 'toynk/LAYOUT.~toy_p_beincongneato', 'type' => 'textbox', 'title' => 'Sizing Chart url (will open link in popup window) [ zoovy:prod_url_sizechart ]' },
'zoovy:prod_url_video' =>  { 'src' => 'kidsafeinc:24242', 'type' => 'legacy' },
'zoovy:prod_utype' =>  {  'origin' => 'satin/LAYOUT.~p-custom_tallpic', 'type' => 'textbox', 'title' => 'Clothing Type' },
'zoovy:prod_video_utube' =>  {  'origin' => 'bamtar/LAYOUT.~bamtar_p_ajaxadd', 'type' => 'textbox', 'title' => 'YouTube Video ID (ex: 6QAE9crPHOY )' },
'zoovy:prod_visa' =>  { 'src' => 'sporks:AUDIO', 'type' => 'legacy' },
'zoovy:prod_w_lining' =>  { 'src' => 'indianselections:AMZNSRK_LAXMI_K_MEEN', 'type' => 'legacy' },
'zoovy:prod_w_top' =>  { 'src' => 'indianselections:AMZNSRK_LAXMI_K_MEEN', 'type' => 'legacy' },
'zoovy:prod_warning' =>  { 'hint' => 'Used to describe any warning associated with the Product', 'title' => 'Product Warning', 'type' => 'text', 'size' => 45 },
'zoovy:prod_warranties' =>  {  'origin' => 'secondact/LAYOUT.~sa_c_dotd_test', 'type' => 'finder', 'title' => 'Product List: Warranties' },
'zoovy:prod_warranties_list' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Extended Warranties (Comma Separated List)' },
'zoovy:prod_warranty' =>  { 'hint' => 'This is the product warranty that will appear on your website.', 'origin' => 'gogoods/LAYOUT.~p-', 'type' => 'textbox', 'title' => 'Warranty' },
'zoovy:prod_weight' =>  { 'hint' => 'Weight of just the product (not the package it\'s shipped in). Used for fulfillment.', 'type' => 'textbox', 'title' => 'Product Weight' },
'zoovy:prod_width' =>  { 'hint' => 'Width of just the product (not the package it\'s shipped in). Used for fulfillment.', 'type' => 'textbox', 'title' => 'Product Width' },
'zoovy:prod_writer' =>  { 'hint' => 'Used to describe Media.', 'title' => 'Writer', 'type' => 'text' },
'zoovy:prod_year' =>  { 'hint' => 'Please enter a the year the movie was released', 'origin' => 'nerdgear/LAYOUT.~p-cd_2pic', 'type' => 'textbox', 'title' => 'Year Released' },
'zoovy:proddesc' =>  { 'src' => 'gssstore:N3822214XX-11', 'type' => 'legacy' },
'zoovy:prodlist' =>  {  'origin' => 'overstockedkitchen/LAYOUT.~overstocked_product', 'type' => 'prodlist', 'title' => 'Product Listing' },
'zoovy:prodlist1_style' =>  {  'origin' => 'ibuystores/LAYOUT.~pf_p_partlocator', 'type' => 'prodlist', 'title' => 'Product List' },
'zoovy:prodlist_custom' =>  {  'origin' => 'secondact/LAYOUT.~sa_c_dotd_test', 'type' => 'prodlist', 'title' => 'Product List: Deal of the Day' },
'zoovy:prodlist_featured' =>  {  'origin' => 'kiwikidsgear/LAYOUT.~kiwikidsgear_product', 'type' => 'prodlist', 'title' => 'Related Items' },
'zoovy:prodlist_related' =>  {  'origin' => 'pbishops/LAYOUT.~pbishops_product', 'type' => 'prodlist', 'title' => 'Related Items' },
'zoovy:prodlist_style' =>  { 'src' => 'sweetwaterscavenger:UM24002AF-T', 'type' => 'legacy' },
'zoovy:product_accessories' =>  { 'src' => 'sweetwaterscavenger:CNF89394MAIN', 'type' => 'legacy' },
'zoovy:product_condition' =>  { 'src' => 'sweetwaterscavenger:UTM14080B', 'type' => 'legacy' },
'zoovy:product_desc' =>  { 'src' => 'autrysports:WINARIDC', 'type' => 'legacy' },
'zoovy:product_line' =>  { 'src' => 'greatstuff:CP38137', 'type' => 'legacy' },
'zoovy:product_msrp' =>  { 'src' => 'atozgifts:ZA39-3129', 'type' => 'legacy' },
'zoovy:product_name' =>  { 'src' => 'gssstore:RAD64002399', 'type' => 'legacy' },
'zoovy:product_seo' =>  { 'src' => 'rusted01:DES_ME2220', 'type' => 'legacy' },
'zoovy:product_seo_title' =>  { 'src' => 'rusted01:DES_ME2220', 'type' => 'legacy' },
'zoovy:product_url' =>  { 'src' => 'abbys:V5PEM2', 'type' => 'legacy' },
'zoovy:producttheme' =>  { 'src' => 'homeandgarden:BS28_6001059', 'type' => 'legacy' },
'zoovy:profile' =>  { 'index'=>'profile', 'src' => '1stproweddingalbums:LIB91TL', 'type' => 'profile' },
'zoovy:prpd_features' =>  { 'src' => 'discountgunmart:54964', 'type' => 'legacy' },
'zoovy:qty' =>  { 'src' => 'guitarelectronics:1101401', 'type' => 'legacy' },
'zoovy:qty_price' =>  {  'origin' => 'brian/LAYOUT.p-20061003', 'type' => 'qtyprice', 'title' => 'Quantity Discount' },
'zoovy:qty_price_txt' =>  {  'origin' => 'wildemats/LAYOUT.~wildemats_p_tabbed_20090719', 'type' => 'text', 'title' => 'Quantity Pricing Text (appears in tab)' },
'zoovy:real_cost' =>  { 'src' => 'sweetwaterscavenger:IXSWTCCTIN379DRCT', 'type' => 'legacy' },
'zoovy:redir' =>  { 'src' => 'mcdc:BANNER4', 'type' => 'legacy' },
'zoovy:redir_url' =>  { 'maxlength' => 128, 'hint' => 'the url this product will redirect to (requires API2 bundle)', 'type' => 'textbox', 'title' => 'Redirect URL', 'size' => 60 },
'zoovy:redirect' =>  { 'src' => 'mcdc:BANNER4', 'type' => 'legacy' },
'zoovy:related-products' =>  { 'src' => 'amigaz:A11B', 'type' => 'legacy' },
'zoovy:related_prod' =>  { 'src' => 'amigaz:A11B', 'type' => 'legacy' },
'zoovy:related_products' =>  { 'popular'=>1, 'index'=>'related_products', 'title' => 'list of related product ids', 'type' => 'finder' },
'zoovy:related_products1' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products2' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products3' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products4' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products5' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products6' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products7' =>  { 'src' => 'dollhousesandmore:CLA70133', 'type' => 'legacy' },
'zoovy:related_products_orig' =>  { 'src' => 'designed2bsweet:DUCKY9', 'type' => 'legacy' },
'zoovy:relatedheading' =>  { 'hint' => 'This test appears above the product list', 'origin' => 'amigaz/LAYOUT.~smhorizimg-2sqimg-prodlist', 'type' => 'text', 'title' => 'Product List Heading' },
'zoovy:relatedproducts' =>  { 'src' => 'polishkitchenonline:003023AX', 'type' => 'legacy' },
'zoovy:relatedroducts' =>  { 'src' => 'amigaz:A11N', 'type' => 'legacy' },
'zoovy:reserve' =>  { 'src' => 'closeoutdude:7653102B', 'type' => 'legacy' },
'zoovy:reserved_qty' =>  { 'src' => 'speedaddictcycles:01-9681', 'type' => 'legacy' },
'zoovy:retail' =>  { 'src' => 'sporks:AUCTIONTEST', 'type' => 'legacy' },
'zoovy:retail_price' =>  { 'src' => 'finale:3GLFE098', 'type' => 'legacy' },
'zoovy:rod_link2' =>  { 'src' => 'ibuystores:NEP0540', 'type' => 'legacy' },
'zoovy:rod_mfgid' =>  { 'src' => 'sweetwaterscavenger:UM24002AF-T', 'type' => 'legacy' },
'zoovy:rss_title' =>  { 'src' => 'lasvegasfurniture:EDPDALTONDB', 'type' => 'legacy' },
'zoovy:search_link1' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_link2' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_link3' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_link4' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_terms5' =>  { 'src' => 'mandwsales:458415', 'type' => 'legacy' },
'zoovy:search_word1' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_word2' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_word3' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:search_word4' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:seo_title' =>  { 'src' => 'lasvegasfurniture:EDPDALTONDB', 'type' => 'legacy' },
'zoovy:serialnum' =>  { 'src' => 'espressoparts2:F_910', 'type' => 'legacy' },
'zoovy:ship2_cost' =>  {  'origin' => 'secondact/LAYOUT.~sa_p_compare', 'type' => 'textbox', 'title' => 'Shipping Cost 2 (second day/front door)' },
'zoovy:ship3_cost' =>  { 'src' => 'ibuystores:NEP0651', 'type' => 'legacy' },
'zoovy:ship_can_cost1' =>  {  'origin' => 'brian/WIZARD.~asdf', 'type' => 'textbox', 'title' => 'Canada Shipping 1st Item' },
'zoovy:ship_can_cost2' =>  {  'origin' => 'sporks/WIZARD.~poop', 'type' => 'readonly', 'title' => 'Canada Shipping (additional item)' },
'zoovy:ship_cost' =>  {  'origin' => 'thesavewave/WIZARD.~tswebay', 'type' => 'textbox', 'title' => 'Shipping Costs' },
'zoovy:ship_cost1' =>  { 'type' => 'currency', 'title' => 'Flat Shipping Cost (first item)' },
'zoovy:ship_cost2' =>  { 'type' => 'currency', 'title' => 'Flat Shipping Cost (additional item)' },
'zoovy:ship_cost3' =>  { 'src' => 'sporks:AUDIO', 'type' => 'legacy' },
'zoovy:ship_exclusive' =>  { 'src' => 'ebestsourc:STEARNSG325ACC', 'type' => 'legacy' },
'zoovy:ship_expcost1' =>  { 'type' => 'currency', 'title' => 'Flat Expedited Shipping Cost (first item)' },
'zoovy:ship_expcost2' =>  { 'type' => 'currency', 'title' => 'Flat Expedited Shipping Cost (additional item)' },
'zoovy:ship_handling' =>  { 'src' => '4my3boyz:SPORFOOTBILLS', 'type' => 'legacy' },
'zoovy:ship_harmoncode' =>  { 'src' => 'beachmart:WRBCWD', 'type' => 'legacy' },
'zoovy:ship_height' =>  { 'src' => 'ebestsourc:STEARNSG325ACC', 'type' => 'legacy' },
'zoovy:ship_info' =>  { 'src' => 'allansjewelry:JWLRY8DIAHEART25525', 'type' => 'legacy' },
'zoovy:ship_ins' =>  { 'src' => '4my3boyz:SPORFOOTBILLS', 'type' => 'legacy' },
'zoovy:ship_insurance' =>  { 'src' => '2bhip:A10-00', 'type' => 'legacy' },
'zoovy:ship_int_cost1' =>  {  'type' => 'currency', 'title' => 'International Shipping' },
'zoovy:ship_int_cost2' =>  { 'type' => 'currency', 'title' => 'International Shipping (addt. item)' },
'zoovy:ship_latency' =>  { 'sku' => 1, 'type' => 'number', 'title' => 'Shipping Latency in days' },
'zoovy:ship_cutoff' =>  { 'sku' => 1, 'type'=>'time', 'title'=>'Shipping Cutoff Time hh:mm' },
'zoovy:ship_origin' =>  { 'sku' => 1, 'type'=>'origin', 'title' => 'Shipping Country|State|Zip ex:US|CA|92008' },
'zoovy:ship_length' =>  { 'src' => 'ebestsourc:STEARNSG325ACC', 'type' => 'legacy' },
'zoovy:ship_markup' =>  { 'src' => '1stproweddingalbums:MIL62', 'type' => 'legacy' },
'zoovy:ship_mfgcountry' =>  { 'type' => 'country', 'title'=>'Country of Manufacturer' },
'zoovy:ship_nmfccode' =>  { 'type' => 'textbox', 'title'=>'National Motor Freight Classification code' },
'zoovy:ship_sortclass' =>  { 'title'=>'shipping sort classification', 'type' => 'textbox', index=>'sortclass' },
'zoovy:ship_weight' =>  { 'hint' => 'Shipping Weight (typically only necessary if base weight does not include packaging)', 'type' => 'textbox' },
'zoovy:ship_width' =>  { 'src' => 'ebestsourc:STEARNSG325ACC', 'type' => 'legacy' },
'zoovy:shipcost' =>  { 'src' => '1stproweddingalbums:LIB91TL', 'type' => 'legacy' },
'zoovy:shipcost2' =>  { 'src' => '1stproweddingalbums:SPORTEN99', 'type' => 'legacy' },
'zoovy:shipping' =>  { 'src' => '4golftraining:ETT1', 'type' => 'legacy' },
'zoovy:shipping_amount' =>  { 'src' => 'scalesusa:ES10000I', 'type' => 'legacy' },
'zoovy:shipping_apiurl' =>  { 'src' => 'ezboston:6301', 'type' => 'legacy' },
'zoovy:shipping_cost' =>  { 'src' => 'outofthetoybox:MD572', 'type' => 'legacy' },
'zoovy:shipping_info' =>  {  'origin' => 'yourdreamizhere/WIZARD.~yourdream', 'type' => 'textarea', 'title' => 'Shipping and Tax' },
'zoovy:shorttitle' =>  {  'origin' => 'summitfashions/WIZARD.~summit23chart', 'type' => 'textbox', 'title' => 'product:zoovy:shorttitle E' },
'zoovy:size' =>  { 'src' => 'kbtdirect:1530-BIKITROPICSGRN', 'type' => 'legacy' },
'zoovy:sku' =>  { 'src' => 'becky:BEC', 'type' => 'legacy' },
'zoovy:sku_pogdesc'=> { 'sku'=>1, 'type'=>'textbox', 'title'=>'SKU Specific Product Description (appended to product title)' },
'zoovy:store_item_address' =>  { 'src' => 'outofthetoybox:MD3337', 'type' => 'legacy' },
'zoovy:subtitle1' =>  { 'src' => 'outofthetoybox:MD572', 'type' => 'legacy' },
'zoovy:subtitle2' =>  { 'src' => 'outofthetoybox:MD572', 'type' => 'legacy' },
#'zoovy:supplier' =>  { 'src' => 'alternativedvd:4G_2000POINTS', 'type' => 'legacy' },
#'zoovy:supplier_id' =>  { 'src' => 'autrysports:024994235255', 'type' => 'legacy' },
#'zoovy:supplier_ship' =>  { 'src' => 'cardiacwellness:WELL-0100P', 'type' => 'legacy' },
#'zoovy:supplierid' =>  { 'src' => 'autrysports:809418050016', 'type' => 'legacy' },
'zoovy:szchart' =>  {  'origin' => 'summitfashions/LAYOUT.~p-1tallpicsizechart', 'type' => 'if', 'title' => undef },
'zoovy:taxable' =>  { 'src' => '1stproweddingalbums:LIB91TL', 'type' => 'boolean' },
#'zoovy:taxible' =>  { 'src' => 'wittonline:1000-BLA', 'type' => 'legacy' },
'zoovy:test' =>  { 'maxlength' => 45, 'type' => 'text', 'title' => 'Text Test', 'size' => 10 },
'zoovy:testattrib' =>  { 'src' => 'mandwsales:10421', 'type' => 'legacy' },
#'zoovy:text2' =>  { 'src' => 'summitfashions:S4A780', 'type' => 'legacy' },
#'zoovy:text55' =>  { 'hint' => 'A URL you paste in here will be linked to on the corresponding image. You need only to put the destination URL and use the proper Zoovy linking syntax. (%SESSION%/category/category.safe.name)<br><br>Go to webdoc #50355 for more information on how to properly set up your links.<br>', 'origin' => 'kiwikidsgear/LAYOUT.~kiwikidsgear_product', 'type' => 'text', 'title' => 'Other Text' },
'zoovy:thumbnail' =>  { 'src' => 'finale:3GLFE098', 'type' => 'legacy' },
'zoovy:title' =>  { 'src' => 'fairdeals:8805', 'type' => 'legacy' },
'zoovy:type' =>  { 'hint' => 'This is the TYPE OF BUTTON that will appear on your website.', 'origin' => 'collectorsarchive/LAYOUT.~p-button_curl', 'type' => 'text', 'title' => 'TYPE' },
'zoovy:ugenre' =>  { 'src' => 'alternativedvd:BLU_1PIECEMOV8', 'type' => 'legacy' },
'zoovy:unlimited' =>  { 'src' => 'guitarelectronics:1101401', 'type' => 'legacy' },
'zoovy:upc' =>  { 'src' => '1stproweddingalbums:LIB80MSQ', 'type' => 'legacy' },
'zoovy:virtual' =>  { 'hint' => 'Tells Zoovy to enable supply chain, and provides hints about supply chain configuration.', 'flexedit' => 0, 'title' => 'Supply Chain Shipping Config', 'type' => 'text', 'size' => 20 },
'zoovy:virtual_ship' =>  { 'src' => 'beachmart:MSRB5915F', 'type' => 'legacy' },
'zoovy:warranty' =>  { 'src' => 'nerdgear:NIWLRT', 'type' => 'legacy' },

	);



##
## based on a comma separated list, loads a set of user defined values.
##
sub userfields {
	my ($USERNAME,$prodref) = @_;

	require ZWEBSITE;
	#my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
	#my $fields = $webdbref->{'flexedit'};
	my $fields = '';

	##
	## so custom attributes (for the user) can now be embedded ..
	##		(and in the future "self registering" by the layout or html wizard.)
	##		see user: uaamerica for more info.
	##
	my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
	my %USERFLEX = ();
	if (defined $globalref->{'@flexedit'}) {
		foreach my $ref (@{$globalref->{'@flexedit'}}) {
			if ($ref->{'id'} eq '') { warn "$USERNAME flexedit field does not have id set."; }
			if (defined $ref->{'type'}) {
				$USERFLEX{$ref->{'id'}} = $ref;
				}
			$fields .= ','.$ref->{'id'};
			}
		}

	my $ref = {};
	my @RESULT = ();
	foreach my $id (split(/,/,$fields)) {
		next if ($id eq '');

		if ((not defined $PRODUCT::FLEXEDIT::fields{$id}) && (not defined $USERFLEX{$id})) {
			## unknown field requested, lets fake it!
			my %unknown = ( id=>"$id", title=>"Unknown field: $id", type=>"text", hint=>"the field $id is unknown to flex edit." );
			push @RESULT, \%unknown;
			}
		elsif (defined $USERFLEX{$id}) {
			push @RESULT, $USERFLEX{$id};
			}
		elsif (not defined $prodref) {
			## since we didn't get a prodref, we shouldn't load the original field.
			push @RESULT, { 'id'=>$id };
			}
		else {
			## valid field requested, we do some simple validation and then send it off!
			my %copy = %{$PRODUCT::FLEXEDIT::fields{$id}};			
			$copy{'id'} = $id;
			## cleanup definitions here.. e.g. validate our internal structure!
			if ($copy{'type'} eq 'text') {
				## valid text fields here.
				}
			push @RESULT, \%copy;
			}			
		}

	return(\@RESULT);
	}


##
## this returns all fields for a given prod ref
##
sub allfields {
	my ($prodref) = @_;

	my $txt = join(",",keys %{$prodref});		
	return(&userfields($txt));
	}


##
## NOTE: this is called by webdoc #51274 
## webdoc!?
sub htmltable {
	my ($format) = @_;
	my $r = '';
	my $i = 0;


	my %fields = ();
	foreach my $k (keys %PRODUCT::FLEXEDIT::fields) {
		$fields{$k} = $PRODUCT::FLEXEDIT::fields{$k};
		}
	require LISTING::EBAY;
	foreach my $ref (@{&LISTING::EBAY::ebay_fields()}) {
		$fields{ $ref->{'id'} } = $ref;
		$ref->{'grp'} = 'ebay';
		}

	my %GROUPS = ();

	foreach my $k (sort keys %fields) {
		if ($fields{$k}->{'popular'}) {
			push @{$GROUPS{'@POPULAR'}}, $k;
			}
		elsif (($fields{$k}->{'legacy'}) || ($fields{$k}->{'type'} eq 'legacy')) {
			push @{$GROUPS{'@LEGACY'}}, $k;
			}
		elsif ($fields{$k}->{'ns'} eq 'profile') {
			push @{$GROUPS{'@PROFILE'}}, $k;
			}
		else {
			push @{$GROUPS{'@OTHER'}}, $k;
			}
		}

	my $body = '';
	foreach my $group ('@POPULAR','@OTHER','@PROFILE','@LEGACY') {
		my $html = '';
		my $txt = '';

		my $TITLE = '';
		if ($group eq '@POPULAR') { $TITLE = 'Popular Fields'; }
		if ($group eq '@OTHER') { $TITLE = 'Less Common Fields'; }
		if ($group eq '@LEGACY') { $TITLE = 'Deprecated/Obsolete Fields'; }
		if ($group eq '@PROFILE') { $TITLE = 'Profile (Inherited) Fields'; }

		foreach my $k (@{$GROUPS{$group}}) {
			my $r = (++$i%2==1)?' valign=top bgcolor="CCCCCC" ':' valign=top';
			my %ref = %{$fields{$k}};
			if ($ref{'type'} eq 'cb') { $ref{'type'} = 'checkbox'; }

			$html .= "<tr>\n";
			$html .= "<td $r valign='top'>";
			$html .= "<b>$k</b>";

			if ($ref{'sku'}) { $html .= "<br><i>*Uses SKU Storage</i>"; }
			if ($ref{'ns'} eq 'profile') { $html .= "<br><i>*Profile Override</i>"; }
			if ($ref{'ns'} eq 'ebay') { $html .= "<br><i>*eBay Listing Event</i>"; }
			$html .= "</td>";
			$html .= "<td $r>";
			$html .= "$ref{'title'}";

			$txt .= "\n== \"$k\" $ref{'title'}\n";

			if ($ref{'hint'} ne '') { 
				$txt .= "$ref{'hint'}\n";
				$html .= "<br><i>$ref{'hint'}</i>"; 
				}

			$html .= "</td>";
			my $typenotes = '';
			if ($ref{'type'} eq 'checkbox') {
				if (not defined $ref{'on'}) { $ref{'on'} = 1; }
				if (not defined $ref{'off'}) { $ref{'off'} = 0; }
				$typenotes = "True: &quot;$ref{'on'}&quot;<br>False: &quot;$ref{'off'}&quot;";
				}
			elsif ($ref{'type'} eq 'select') {
				my $diff = 0;
				foreach my $opt (@{$ref{'options'}}) {
					if ($opt->{'p'} ne $opt->{'v'}) { $diff++; }
					}
	
				foreach my $opt (@{$ref{'options'}}) {
					if (not $diff) { $typenotes .= "\"$opt->{'v'}\", "; }
					else { $typenotes .= "$opt->{'p'} = \"$opt->{'v'}\"<br> "; }
					}
				$typenotes = "Valid values:<br>$typenotes";
				}
			elsif (($ref{'type'} eq 'textbox') || ($ref{'type'} eq 'text')) {
				if ($ref{'size'}) { $typenotes = "<br>Input Size: $ref{'size'}"; }
				if ($ref{'maxlength'}) { $typenotes = "<br>Max Length: $ref{'maxlength'}"; }
				}
			$html .= "<td $r>";
			$html .= "$ref{'type'}";
			if ($typenotes ne '') { $html .= "<br><i>$typenotes</i>"; }
			$txt .= "* Type: $ref{'type'}\n";
			if ($typenotes ne '') {
				$typenotes = &ZTOOLKIT::htmlstrip(&ZOOVY::dcode($typenotes));
				foreach my $line (split(/\n/,$typenotes)) {
					next if ($line eq '');
					$txt .= "* $line\n";
					}
				}
			$txt .= "\n";

			$html .= "</td>";
			$html .= "</tr>\n";
			}

	if ($format eq 'txt') {	
		$body .= "\n================================================================================================\n";
		$body .= "$TITLE\n$txt\n\n";
		}
	else {
		$body .= qq~
	<h2>$TITLE</h2>
	<table>
	<tr>
		<td><b>Attribute</td>
		<td><b>Title</b></td>
		<td><b>Format</td>
	</tr>
	$html
	</table>
	~;
		}
	}

	if ($format eq 'txt') {
		}
	else {
		$body .= qq~<i>Total Attributes: $i</i><br>~;
		}

	return($body);
	}

##
##
##


## yipes! used for non-products

sub save { die(); }
sub prodsave {
	my ($P,$flexfields,$formref, %options) = @_;

	my $dataref = undef;
	if (not defined $P) {
		$dataref = $options{'%dataref'};	# used for decal save
		}

	my $skulist = undef;
	my $has_sku_fields = 0;
	foreach my $ref (@{$flexfields}) {
		if ($ref->{'sku'}) { $has_sku_fields++; }
		}

	if (not $has_sku_fields) {
		}
	elsif ($P->has_variations('inv')) {
		($skulist) = $P->list_skus();
		}

	my $changes = 0;
	my @SKUS = ();
	foreach my $ref (@{$flexfields}) {
		my $id = $ref->{'id'};
		my $val = $formref->{ $id };
		print STDERR "ID[$id] VAL[$val]\n";
	
		if ((defined $skulist) && ($ref->{'sku'})) {
			push @SKUS, $ref;
			$id = undef;
			}
		next if (not defined $id);	# we'll handle this in the sku specific portion

		if ($ref->{'type'} eq 'selectreset') {
			$ref->{'properties'} |= 1;	# enable the delete on blank setting
			$ref->{'type'} = 'select';
			}
		#if ((defined $ref->{'unset'}) && ($ref->{'unset'} eq $val)) {
		#	$val = '';
		#	$ref->{'properties'} |= 1;
		#	}

		if ($ref->{'type'} eq 'checkbox' || $ref->{'type'} eq 'cb' || $ref->{'type'} eq 'boolean') {
			## checkbox never returns a false, so we have to insert it
			if (not defined $ref->{'on'}) { $ref->{'on'} = 1; }
			if (not defined $ref->{'off'}) { $ref->{'off'} = 0; }

			if (defined $val) { $val = $ref->{'on'}; }
			else { $val = $ref->{'off'}; }
			}		

		if ($ref->{'type'} eq 'number') {
			if ($ref->{'format'} eq 'currency') {
			# 	$ref->{'format'} 
				}
			}

		if ($ref->{'type'} eq 'mselect') {
			# multiselect is a little interesting .. so we'll interate
			my @vals = ();

			my $delim = $ref->{'delim'};
			if ((not defined $delim) || ($delim eq '')) { $delim = '|'; }

			foreach my $chkkey (keys %{$formref}) {
				print STDERR "KEY $chkkey $formref->{$chkkey}\n";
				next if ($formref->{$chkkey} ne 'on');	# we don't have a select box, ignore this.
				my ($id,$v) = split(/\!/,$chkkey,2);		# chkkey will be $id!$v 
				print STDERR "KEY2 $id $v\n";
				next if ($id ne $ref->{'id'});			# this is not the checkbox you're looking for.
				print STDERR "KEY3: $v\n";
				push @vals, $v;
				}

			# push @vals, "cheese";
			# push @vals, "xyz";
			
			$val = join($delim,@vals);
			}
			
		if ($ref->{'type'} eq 'prtchooser') {
			## prtchooser stores a bit, per partition. which records an on/off on a per partition basis.
			$val = 0;
			foreach my $field (keys %{$formref}) {
				## amz:prts.1 (partition 1)
				if ($field =~ /^$id\.([\d]+)/) { 
					$val += (1<<$1);
					delete $formref->{$field};
					}
				}
			}
		
		## hmmm.. bizarre, no formref data was passed (not even blank!)
		next if (not defined $val);

		if (($val eq '') && ($ref->{'properties'}&1)) {
			## if blank, and properties&1 then nuke!
			if (not defined $P) {
				if (defined $dataref->{$id}) { $changes++; }
				delete $dataref->{$id};
				}
			else {
				if (defined $P->fetch($id)) { $changes++; }
				$P->store($id,undef);
				}
			}
		else {
			if (not defined $P) {
				$changes += ($dataref->{$id} eq $val)?1:0;
				$dataref->{$id} = $val;
				}
			else {
				$changes += $P->store($id,$val);
				}
			}			
		}

	## handle any SKU specific fields
	if (scalar(@SKUS)>0) {
		foreach my $skuset (@{$skulist}) {
			my ($sku,$skuref) = @{$skuset};
			foreach my $ref (@SKUS) {
				my $id = "$sku|$ref->{'id'}";
				my $val = $formref->{ $id };

				if (($val eq '') && ($ref->{'properties'}&1)) {
					## if blank, and properties&1 then nuke!
					#if (defined $mref->{$ref->{'id'}}) { $changes++; }
					#delete $mref->{$ref->{'id'}};
					$changes += $P->skustore($sku,$ref->{'id'},undef);
					}
				else {
					# $mref->{ $ref->{'id'} } = $val;
					print STDERR "SKUSTORE: $sku $ref->{'id'} $val\n";
					$changes += $P->skustore($sku,$ref->{'id'},$val);
					}			
				}

			#if ($sku ne $PID) { 
			#	## if $sku is equal to $PID then we've already set attributes, no need to re-serialize $mref
			#	&ZOOVY::serialize_skuref($prodref,$sku,$mref);
			#	}
			}
		}
	
	return($changes);
	}



##
##
##
sub input_text {
	my ($id,$val,$prodref,$ref) = @_;

	my $html = '';
	if (defined $ref->{'size'}) {}
	elsif ((defined $ref->{'format'}) && (($ref->{'format'} eq 'currency') || ($ref->{'format'} eq 'number'))) {
		$ref->{'size'} = 5;
		}
	else { $ref->{'size'} = 20; }

	if (not defined $ref->{'maxlength'}) { $ref->{'maxlength'} = 45; }
	if ($ref->{'maxlength'} < $ref->{'size'}) { $ref->{'maxlength'} = $ref->{'size'}; }

	my $qt = &ZOOVY::incode($val);
	$html .= qq~<input type=textbox name="$id" value="$qt" size="$ref->{'size'}" maxlength="$ref->{'maxlength'}" class='flextextbox'>~;
	return($html)
	}



##
## a textlist is a textarea that auto-expands to a "max" number of lines (10 is default)
##
sub input_textlist {
	my ($id,$val,$prodref,$ref) = @_;

	use Data::Dumper;
	print STDERR "input_textlist ".Dumper($id,$val,$prodref,$ref);
	my $html = '';
	if (not defined $ref->{'max'}) { $ref->{'max'} = 10; }
	if (not defined $ref->{'maxlength'}) { $ref->{'maxlength'} = 10; }

	## apparently perl doesnt like passing from a split to a scaler. doing so causes webdoc 51274 not to open. we have to pass to an array first to avoid this.  
	my @start_rows = split(/[\n\r]+/,$val);
	my $START_ROWS = scalar(@start_rows);
	if ($START_ROWS == 0) { $START_ROWS = 1; }
	$START_ROWS++;
	if ($START_ROWS > $ref->{'max'}) { $START_ROWS = $ref->{'max'}; }

	my $qt = &ZOOVY::incode($val);
	$html .= qq~<div><textarea cols="$ref->{'maxlength'}" rows="$START_ROWS" onFocus="this.rows='$ref->{'max'}';" onBlur="this.rows='$START_ROWS'" name="$id" class='flextextarea flextextarearesize'>$qt</textarea></div>~;
	$html .= sprintf(qq~<div class="hint">one entry per line - max:%d</div>~,$ref->{'maxlength'});
	return($html)
	}


##
##
##
sub input_hidden {
	my ($id,$val,$prodref,$ref) = @_;

	my $html = '';
	my $qt = &ZOOVY::incode($val);
	$html .= qq~<input type=hidden name="$id" value="$qt">~;
	return($html)
	}

##
##
##
sub input_select {
	my ($id,$val,$prodref,$ref) = @_;

	my $myhtml = '';
	my $found = 0;
	foreach my $set (@{$ref->{'options'}}) {
		my $selected = '';
		if ($set->{'v'} eq $val) { 
			$selected = 'selected'; $found++;
			}
		$myhtml .= "<option $selected value=\"$set->{'v'}\">$set->{'p'}</option>\n";
		}

	if ((not $found) && ($val eq '')) {
		$myhtml = "<option value=\"\">-- please select --</option>\n$myhtml";
		}
	elsif (not $found) { 
		$myhtml = "<option value=\"".&ZOOVY::incode($val)."\">**INVALID**($val)</option>\n$myhtml";
		}
	$myhtml = qq~<select name="$id">$myhtml</select>~;

	return($myhtml);
	}

##
##
##
sub input_cb {
	my ($id,$val,$prodref,$ref) = @_;

	my $html = '';
	if (not defined $ref->{'on'}) { $ref->{'on'} = 1; }
	if (not defined $ref->{'off'}) { $ref->{'off'} = 0; }

	my $title = $ref->{'title'};
	if (not defined $title) { $title = 'Enabled'; }

	my $checked = ($val eq $ref->{'on'})?'checked':'';
	$html = qq~<input type="checkbox" $checked name="$id"> $title~;
	return($html);
	}


%PRODUCT::FLEXEDIT::INPUT = (
	'text'=>\&input_text,
	'cb'=>\&input_cb,
	'select'=>\&input_select,
	);

##
##	currently all input date types must have format YYYYMMDD
## 	(there are plans to add datetime and time input types)
##
sub input_date {
	my ($id,$val,$prodref,$ref) = @_;

	my $html = '';
	$ref->{'size'} = 8;	## YYYYMMDD
	$ref->{'maxlength'} = 8;

	my $qt = &ZOOVY::incode($val);
	$html .= qq~<input type=textbox name="$id" value="$qt" size="$ref->{'size'}" maxlength="$ref->{'maxlength'}" class='flextextbox'>~;
	return($html)
	}


##
## %options
##		form (form id is required for some popups ex: ebay/chooser)
##
sub output_html {
	my ($P,$flexfields,%options) = @_;

	my $PRT = $options{'PRT'};

	my $USERNAME = $options{'USERNAME'};
	if (not defined $USERNAME) {
		$USERNAME = $P->username();
		}

	my $PID = undef;
	my $prodref = undef;
	if (ref($P) eq 'PRODUCT') {
		$PID = $P->pid();
		$prodref = $P->prodref();
		}
	else {
		$prodref = $options{'%dataref'};		## NOTE: also used for decals
		}

	## note: there is no leading <table> or </table>

	my $html = "<div class='hint'>You currently have no custom fields.</div>";

	## phase1: normalize types
	my $has_sku_fields = 0;
	foreach my $flexref (@{$flexfields}) {
	
		if ($flexref->{'type'} eq 'textbox') { $flexref->{'type'} = 'text'; }
		if ($flexref->{'type'} eq 'keyword') { $flexref->{'type'} = 'text'; }
		if ($flexref->{'type'} eq 'currency') { $flexref->{'type'} = 'text'; $flexref->{'format'} = 'currency'; }
		if ($flexref->{'type'} eq 'number') { $flexref->{'type'} = 'text'; $flexref->{'format'} = 'number'; }
		if ($flexref->{'type'} eq 'weight') { $flexref->{'type'} = 'text'; }
		if ($flexref->{'type'} eq 'checkbox') { $flexref->{'type'} = 'cb'; }
		if ($flexref->{'type'} eq 'digest') { $flexref->{'type'} = 'hidden'; }
		if ($flexref->{'type'} eq 'special') { $flexref->{'type'} = 'hidden'; }
		if ($flexref->{'type'} eq 'boolean') { $flexref->{'type'} = 'cb'; }
		if ($flexref->{'type'} eq 'chooser/counter') { $flexref->{'type'} = 'text'; }
		#if ($flexref->{'type'} eq 'ebay/storecat') { 
		#	$flexref->{'type'} = 'select'; 
		#	require EBAY2;
		#	my ($ebayStoreCats) = &EBAY2::fetchStoreCats($USERNAME,prt=>$PRT);
		#	if (defined $ebayStoreCats) {
		#		foreach my $r (@{$ebayStoreCats}) {
		#			## set p/v values which are needed by flexedit
		#			$r->{'p'} = "($r->{'catID'}) $r->{'catPath'}";
		#			$r->{'v'} = $r->{'catID'};
		#			}
		#		$flexref->{'options'} = $ebayStoreCats;
		#		}
		#	}
		if ($flexref->{'type'} eq 'ebay/attributes') { $flexref->{'type'} = 'text'; }
		# if ($flexref->{'type'} eq 'ebay/category') { $flexref->{'type'} = 'text'; $flexref->{'format'} = 'number'; }
		if ($flexref->{'type'} eq 'overstock/category') { $flexref->{'type'} = 'text'; }
		if ($flexref->{'type'} eq 'selectreset') { $flexref->{'type'} = 'select'; $flexref->{'properties'} |= 1; }
		

		if ($flexref->{'type'} eq 'cb') { 
			$flexref->{'!cols'} = 1; 
			}
		elsif ($flexref->{'type'} eq 'textlist') {
			## a textarea box that auto-expands
			if (defined $flexref->{'!cols'}) {}
			elsif (not defined $flexref->{'maxlength'}) {}
			elsif ($flexref->{'maxlength'}<10) { $flexref->{'!cols'} = 1; }
			elsif ($flexref->{'maxlength'}>50) { $flexref->{'!cols'} = 5; }
			elsif ($flexref->{'maxlength'}>30) { $flexref->{'!cols'} = 3; }
			}
		elsif ($flexref->{'type'} eq 'text') { 

			if (defined $flexref->{'!cols'}) {}
			elsif (not defined $flexref->{'size'}) {}
			elsif ($flexref->{'size'}<10) { $flexref->{'!cols'} = 1; }
			elsif ($flexref->{'size'}>50) { $flexref->{'!cols'} = 5; }
			elsif ($flexref->{'size'}>30) { $flexref->{'!cols'} = 3; }
	
			if (defined $flexref->{'!cols'}) {}
			if ($flexref->{'format'} eq 'currency') { $flexref->{'!cols'} = 1; }
			elsif ($flexref->{'format'} eq 'number') { $flexref->{'!cols'} = 1; }
		
			if (not defined $flexref->{'!cols'}) { $flexref->{'!cols'} = 2; }
			}
		elsif ($flexref->{'type'} eq 'select') { 
			$flexref->{'!cols'} = 2; 
			my $is_small = 1;
			foreach my $opt (@{$flexref->{'options'}}) {
				if (length($opt->{'p'})>20) { $is_small = 0; }
				}
			if ($is_small) { $flexref->{'!cols'} = 1; }
			}
		else { 
			$flexref->{'!cols'} = 3; 
			}

		if ($flexref->{'sku'}) { $has_sku_fields++; }
		}


	my $skulist = undef;
	if (not $has_sku_fields) {
		}
	elsif ($P->has_variations('inv')) {
		($skulist) = $P->list_skus();
		}



	## gracefully default to '' so we don't get undef errors
	if (not defined $options{'form'}) { $options{'form'} = '';  }

	## phase2: come up with a strategy for what is single, dual, and three column formats
	my $pos = 0; 
	my $lastref = undef;
	my $width = '19%';

	$html = '';
	my @SKUS = ();
	foreach my $flexref (@{$flexfields}) {

		my $id = $flexref->{'id'};
		if ((defined $skulist) && ($flexref->{'sku'})) {
			push @SKUS, $flexref;
			$id = undef;
			}
		#sku specific options aren't handled here.
		next if (not defined $id);

# a container div around all the form elements with a class of flexeditor could be added so that it didn't need to be added here on each div.

		$html .= "<div class='flexeditor' style='float:left; margin:5px; width: $width%'>";

		if ($flexref->{'type'} eq 'variation') {	
			## amazon variation (don't display)
			}
		elsif ($flexref->{'type'} eq 'hidden') {
			}
		elsif (defined $id) {
			my $title = $flexref->{'title'};
			if ((not defined $title) && (defined $flexref->{'hint'})) { $title = "Attribute[$id] $flexref->{'hint'}"; }
			if (not defined $title) { $title = "Attribute[$id]"; }
			$html .= qq~<div class='zoovysub2header' style='margin-bottom:2px;'>$title</div>~;
			}
		else {
			require Data::Dumper;
			$html .= qq~<div class=zoovysub1header>~.Data::Dumper::Dumper($flexref).qq~</div>~;
			}

		next if (not defined $id);
		my $val = $prodref->{ $id };

		if ($flexref->{'type'} eq 'text') {
			$html .= &input_text($id,$val,$prodref,$flexref);
			}
		elsif ($flexref->{'type'} eq 'date') {
			$html .= &input_date($id,$val,$prodref,$flexref);
			}
		elsif (($flexref->{'type'} eq 'textarea') || ($flexref->{'type'} eq 'keywordlist')) {
			my $qt = &ZOOVY::incode($prodref->{ $id });
			if (not $flexref->{'rows'}) { $flexref->{'rows'} = 3; }
			if (not $flexref->{'cols'}) { $flexref->{'cols'} = 60; }
			$html .= qq~<textarea class="flextextarea" name="$id" rows="$flexref->{'rows'}" cols="$flexref->{'cols'}">$qt</textarea>~;
			}
		elsif ($flexref->{'type'} eq 'textlist') {
			$html .= &input_textlist($id,$val,$prodref,$flexref);
			}
		elsif ($flexref->{'type'} eq 'prtchooser') {
# commented this out because hints are now added to all fields.  JT 2010/07/27
#			$html .= "<div class='hint'>$flexref->{'hint'}</div>";
			my $val = int($prodref->{ $id });
			my $i = 0;
			foreach my $prttxt (@{&ZWEBSITE::list_partitions($USERNAME)}) {
				my ($prt,$txt) = split(/:/,$prttxt);
				my $bw = 1<<int($prt);
				my $checked = (($val & $bw)>0)?'checked':'';
				$html .= qq~<input $checked name="$id.$prt" type='checkbox'>$prttxt<br>~;
				}
			}
		elsif ($flexref->{'type'} eq 'variation') {
			## amazon variation (don't display, not editable)
			}
		elsif ($flexref->{'type'} eq 'hidden') {
			$html .= &input_hidden($id,$val,$prodref,$flexref);
			}
		elsif ($flexref->{'type'} eq 'finder') {
			$html .= qq~
<input type="button" value=" Product Accessories " onClick="adminApp.ext.admin.a.showFinderInModal('PRODUCT','$PID','$id'); return false;">
~;

			}
		elsif ($flexref->{'type'} eq 'cb') {
			my $val = $prodref->{ $id };
			$html .= &input_cb($id,$val,$prodref,$flexref);
			}
		elsif ($flexref->{'type'} eq 'select') {
			my ($myhtml) = input_select($id,$val,$prodref,$flexref);
			$html .= $myhtml;
			}
		elsif ($flexref->{'type'} eq 'mselect') {
			my %vals = ();	# a list of selected values.

			my $delim = $flexref->{'delim'};
			if ((not defined $delim) || ($delim eq '')) { $delim = '|'; }
			$delim = quotemeta($delim);
			foreach my $v (split($delim,$prodref->{ $id })) { $vals{$v}++; }

			my @LINES = ();
			foreach my $set (@{$flexref->{'options'}}) {
				my $selected = '';
				if ($vals{$set->{'v'}}) { 
					$selected = 'checked'; 
					$vals{$set->{'v'}}++; 
					}
				push @LINES, "<input type=\"checkbox\" $selected name=\"$id!$set->{'v'}\"> $set->{'p'}<br>\n";
				}
			foreach my $v (keys %vals) {
				next unless ($vals{$v}==1); ## if we're 1, we were found in the product data, but not in the list of allowed values.
				push @LINES, "<input type=\"checkbox\" checked name=\"$id!$v\"> ** INVALID ** $v<br>\n";
				}

			my $myhtml = '';
#			if ($i%3!=0) { $myhtml .= "</tr>"; }
			$myhtml = "<table width=100% cellspacing='0' cellpadding='0'><tr><td class='flexeditor'>$myhtml</td></tr></table>";

			#if (not $found) { 
			#	$myhtml = "<input type= value=\"".&ZOOVY::incode($val)."\">**INVALID**($val)</option>\n$myhtml";
			#	}
			# use Data::Dumper; $html .= Dumper($flexref);
			$html .= qq~$myhtml~;
			}
		elsif ($flexref->{'type'} eq 'image') {
			my $attrib = $id;

			my $img = $prodref->{ $attrib };
			my $imgpretty = ($img)?$img:'Not Set';
			
			my $value = $prodref->{ $attrib };
			my $url = &ZOOVY::mediahost_imageurl($USERNAME, $prodref->{ $attrib }, 110, 110, 'FFFFFF', 1);
			if ($url eq '') { $url = "/images/image_not_selected.gif"; }

			$html .= "<img name=\"${attrib}img\" id=\"${attrib}img\" width=50 height=50 src=\"$url\"><br>";
			$html .= "<input type=hidden id=\"$attrib\" name=\"$attrib\" value=\"$img\">\n";
			$html .= "<button class=\"minibutton\" onClick=\"mediaLibrary(
				jQuery(adminApp.u.jqSelector('#','${attrib}img')),
				jQuery(adminApp.u.jqSelector('#','${attrib}')),
				'$flexref->{'prompt'}');
				return false;
				\">Select</button>";
			$html .= "<button class=\"minibutton\" onClick=\"
				jQuery(adminApp.u.jqSelector('#','${attrib}img')).attr('src','/images/blank.gif');
				jQuery(adminApp.u.jqSelector('#','${attrib}')).val('');
				return false;
				\">Clear</button>";
			}
		elsif ($flexref->{'type'} eq 'button') {
			$html .= qq~<input type="checkbox" name="$id"> Click box and hit save to run macro\n~;
			#use Data::Dumper;
			#$html .= Dumper($flexref);
			}
		elsif ($flexref->{'type'} eq '') {
			$html .= "Error 'type' attribute not set on: ".Dumper($flexref); 
			}
		elsif ($flexref->{'type'} eq 'chooser/counter') {
			$html .= '<!-- Counter Chooser Goes Here -->';
			}
		elsif ($flexref->{'type'} eq 'chooser/ebaystorecat') {
			$html .= '<!-- eBay Store Category Chooser Goes Here -->';
			}
		elsif ($flexref->{'type'} eq 'chooser/ebayattributes') {
			$html .= '<!-- eBay Store Category Chooser Goes Here -->';
			}
		elsif ($flexref->{'type'} eq 'ebay/category') {
			$html .= qq~
<INPUT TYPE="text" class="text" id="$id" NAME="$id" onChange="this.value = validated('.0123456789',this.value)" VALUE="$val" SIZE="9">
<input type="button" class="button2" value=" Choose " onClick="openWindow('/biz/ebay/catchooser2008/index.cgi?FRM=$options{'form'}&PID=$PID&V=$id');">
			~;
			}
		else {
			$html .= "Unknown type: $flexref->{'type'}"; 
			}

#always put the hint at the end. jt 2010/07/27
		if ($flexref->{'hint'}) {
			$html .= "<div class='hint'>$flexref->{'hint'}</div>";
			}

#		$html .= "</td>";
		$html .= "</div>";
#		if ($flexref->{'!end'}) { $html .= "</tr>"; }
		}

		if (scalar(@SKUS)>0) {
# the clear:both below gives each sku specific entry it's own horizontal plane.
			$html .= qq~<div style='clear:both;'></div>
	<div style='padding-top:5px;' class='flexeditor'>
	<table class='zoovytable' cellspacing='1' cellpadding='4'>~;

			$html .= qq~<thead class="zoovytableheader"><tr>
	<th>SKU</th>
	<th>Description</th>
~;
			foreach my $flexskuref (@SKUS) {
				$html .= "<th>$flexskuref->{'title'}</th>";
				}
			$html .= qq~</tr></thead><tbody>~;

			foreach my $skuset (@{$skulist}) {
				my ($sku,$skuref) = @{$skuset};
				if ($sku eq $PID) {
					$skuref = $prodref;
					}

				$html .= "<tr>";
				$html .= "<td>$sku</td>";	
				$html .= "<td>$skuref->{$sku}</td>";
				foreach my $flexskuref (@SKUS) {
					my $id = "$sku|$flexskuref->{'id'}";
					my $val = $skuref->{$flexskuref->{'id'}};
					if ($flexskuref->{'type'} eq 'text') {
						$html .= "<td>".&input_text($id,$val,$prodref,$flexskuref)."</td>";
						}
					elsif ($flexskuref->{'type'} eq 'select') {
						$html .= "<td>".&input_select($id,$val,$prodref,$flexskuref)."</td>";
						}
					elsif ($flexskuref->{'type'} eq 'date') {
						$html .= "<td>".&input_date($id,$val,$prodref,$flexskuref)."</td>";
						}
					elsif ($flexskuref->{'type'} eq 'cb') {
						$html .= "<td>".&input_cb($id,$val,$prodref,$flexskuref)."</td>";
						}
					elsif ($flexskuref->{'type'} eq 'image') {
						## https://admin.zoovy.com/support/index.cgi?ACTION=VIEWTICKET&TICKET=2030159&USERNAME=summitfashions
						$html .= "<td>".&input_text($id,$val,$prodref,$flexskuref)."</td>";
						}
					
					}
				$html .= "</tr>";
				}
			$html .= qq~</tbody></table></div>
			<!-- <a href="http://www.youtube.com/watch?v=7FbNZTlt86w">Got a problem?</a> -->
			~;
			}

#  seems odd to add a table around it, when the point is to get rid of tables. jt 20110118
#	$html = qq~<table width=100% cellpadding='5' cellspacing='0'>$html</table>~;
	
	## the div below will end any "float" behavior and start fresh
	$html .= q~<div style="clear:both"></div>~;

	return($html);
	}

1;







