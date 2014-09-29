package ELASTIC;

use strict;

use Data::Dumper;
use Elasticsearch::Bulk;
use lib "/backend/lib";
require PRODUCT::FLEXEDIT;
require PRODUCT;
require ZOOVY;
require ZWEBSITE;
require DBINFO;
require ZTOOLKIT;
require CART2;



#sub private_search {
#
#	my $USERNAME = 'kcint';
#	my ($es) = &ZOOVY::getElasticSearch($USERNAME);
#	my %params = ();
#	$params{'index'} = sprintf("%s.private",lc($USERNAME));
#	# $params{'query'} = { "query_string"=>{ "query"=>"350595101128" } };
#	$params{'query'} = { "query_string"=>{ "query"=>"2012-10-115155" } };
#	
#	print Dumper($es->search(%params));
#
#	}


#sub reindex_orders {
#	my ($USERNAME) = @_;
#
#	my ($es) = &ZOOVY::getElasticSearch($USERNAME);
#	&ELASTIC::rebuild_private_index($USERNAME);
#	require ORDER::BATCH;
#	my ($r) = &ORDER::BATCH::report($USERNAME);
#	foreach my $set (@{$r}) {
#		my ($O2) = CART2->new_from_oid($USERNAME
#		print Dumper($r);
#		die();
#		}
#	}




@ELASTIC::ES_PAYLOADS = ();

##
##
##	$PIDSREF = [ $P1 , $P2 , $P3 ]
##
## optional parameters:
##		*es => references to elastic search object
##
sub add_products {
	my ($USERNAME, $PRODUCTSAR, %options) = @_;

	my ($es) = $options{'*es'};
	if (not defined $es) { $es = &ZOOVY::getElasticSearch($USERNAME); }
	my $ESINDEX = $options{'index'} || lc("$USERNAME.public");

	my ($bulk) = Elasticsearch::Bulk->new('es'=>$es,'index'=>$ESINDEX);
	my ($FIELDSREF,$IMAGE_FIELDSREF) = &PRODUCT::FLEXEDIT::elastic_fields($USERNAME,'gref'=>$options{'gref'});

	foreach my $P (@{$PRODUCTSAR}) {
		next if (not defined $P);
		print "P: ".$P->pid()."\n";
		my $ES_PAYLOADS = $P->elastic_index( $FIELDSREF, $IMAGE_FIELDSREF );

		if (defined $bulk) {
			## ES requires we specify a command ex: 'index'
			my @ES_BULK_ACTIONS = ();
			foreach my $payload (@{$ES_PAYLOADS}) {
				# push @ES_BULK_ACTIONS, { 'index'=>$payload };
				push @ELASTIC::ES_PAYLOADS, $payload;
				if (defined $payload->{'data'}) { warn "payload contains legacy ->data attribute\n"; }
				## print STDERR Dumper($payload);
				$bulk->index($payload)
				}

			#my $result = $es->bulk({
			#	index	=> lc("$USERNAME.public"),		## we specify this at the top, so we don't need to in each payload
			#	actions=>\@ES_BULK_ACTIONS,
			#	replication=>'async',
			#	});
			## print STDERR Dumper(\@ES_BULK_ACTIONS,$result);
			}

		}
	$bulk->flush();
	}



#########################################################################################
##
##
##
sub rebuild_private_index {
	my ($USERNAME,%options) = @_;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my ($es) = &ZOOVY::getElasticSearch($USERNAME);

	if ($options{'NUKE'}) {
		if ($es->indices->exists("index"=>lc("$USERNAME.private"))) {
			$es->indices->delete("index"=>lc("$USERNAME.private"));
			}

		my %order_properties = (
			'orderid'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>1 },
			'customer'=>{ 'type'=>'long', 'store'=>'yes', 'include_in_all'=>0 },
			'pool'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>1 },
			'erefid'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>1 },
			'mkts'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'payment_methods'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'payment_status'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>3, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'review_status'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>3, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'domain'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>45, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			#'sears_orderid'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>45, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			#'google_orderid'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>45, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'po_number'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>45, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'refer'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'prt'=>{ 'type'=>'integer' },
			# 'phone'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'references'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },

			'items_total'=>{ 'type'=>'long', 'store'=>'yes', 'include_in_all'=>0 },
			'cart_created_ts'=>{ 'type'=>'date', 'format'=>'yyyy/MM/dd HH:mm:ss||yyyy/MM/dd', 'store'=>'no', 'include_in_all'=>0 },
			'cart_order_ts'=>{ 'type'=>'date', 'format'=>'yyyy/MM/dd HH:mm:ss||yyyy/MM/dd',  'store'=>'no', 'include_in_all'=>0 },
			'paid_ts'=>{ 'type'=>'date', 'format'=>'yyyy/MM/dd HH:mm:ss||yyyy/MM/dd',  'store'=>'no', 'include_in_all'=>0 },
			'shipped_ts'=>{ 'type'=>'date', 'format'=>'yyyy/MM/dd HH:mm:ss||yyyy/MM/dd', 'store'=>'no', 'include_in_all'=>0 },
			'ip_address'=> { 'type'=>'ip', 'store'=>'no', 'null_value'=>'0.0.0.0', 'include_in_all'=>0 },
			#	## REVIEW
			#	## PAYMENT
			# 'payment_tokens'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			# 'shipping_methods'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			# 'tracking_methods'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>1 },

			'order_total'=>{ 'type'=>'integer', 'store'=>'no', 'include_in_all'=>1 },
			'prt'=>{ 'type'=>'integer', 'store'=>'no', 'include_in_all'=>1 },
			'profile'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'shp_method'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'flags'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'fullname'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>65, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'email'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>65, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },					
			#	'shipping_total'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'integer', 'store'=>'no', 'include_in_all'=>1 },
			#	'date_created'=>{ 'type'=>'date', 'format'=>'YYYY-mm-dd', 'store'=>'no', 'include_in_all'=>0 },
			#	'date_shipped'=>{ 'type'=>'date', 'format'=>'YYYY-mm-dd','store'=>'no', 'include_in_all'=>0 },
			#	'date_paid'=>{ 'type'=>'date', 'format'=>'YYYY-mm-dd','store'=>'no', 'include_in_all'=>0 },
			#	'ip'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			);

		my %address_properties = (
			'email'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>65, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'company'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'type'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>1, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'firstname'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>25, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'lastname'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>25, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'phone'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>12, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'address1'=>{ 'analyzer'=>'standard', 'buffer_size'=>65, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'address2'=>{ 'analyzer'=>'standard', 'buffer_size'=>65, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'city'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>35, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'region'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>15, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'postal'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>10, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },				
			'countrycode'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>2, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 }
			);

		my %shipment_properties = (
			'carrier'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>3, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'track'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>25, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 },
			'created'=>{ type=>'date', 'format'=>'yyyy/MM/dd HH:mm:ss||yyyy/MM/dd' },
			'luser'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>10, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			);

		my %payment_properties = (
			'ps'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>3, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'txn'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'acct'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'auth'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'TN'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'PO'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'AO'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'GO'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'GA'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'BO'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'RM'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'CM'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'C4'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>16, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 },
			'WI'=>{ 'type'=>'integer', 'store'=>'no', 'include_in_all'=>0 },
			'created_date'=>{ type=>'date', 'format'=>'YYYY-mm-dd' },
			);

		my %item_properties = (
			'sku'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'mkt'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'mktid'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'mktuser'=>{ 'analyzer'=>'lcKeyword', 'buffer_size'=>20, 'type'=>'string', 'store'=>'yes', 'include_in_all'=>0 },
			'qty'=>{ 'type'=>'integer', 'store'=>'yes', 'include_in_all'=>0 },
			'price'=>{ 'type'=>'integer', 'store'=>'yes', 'include_in_all'=>0 },
			);

		foreach my $k (keys %CART2::VALID_FIELDS) {
			my $ref = $CART2::VALID_FIELDS{$k};
			next if (not defined $ref->{'es'});

			if ($ref->{'es'} =~ /^(ship|bill)\//) {
				## address fields
				}
			elsif (defined $order_properties{ $ref->{'es'} }) {
				}
			elsif (substr($ref->{'es'},0,1) eq '*') {
				## special field (*REFERENCES)
				}
			else {
				print Dumper($ref);
				die();
				}
			}

		$es->indices->create(
			index => "$USERNAME.private",
			'body'=>{
				'mappings' => { 
					'order' => {
						'date_detection' => 'false',
						'dynamic'=>'strict',
						'properties'=>\%order_properties,
						},
					'order/address'=>{
						'date_detection' => 'false',
						'dynamic'=>'strict',
						'_parent'=>{ 'type'=>'order', },
						'properties'=>\%address_properties,
						},
					'order/shipment'=>{
						'date_detection' => 'false',
						'dynamic'=>'strict',
						'_parent'=>{ 'type'=>'order', },
						'properties'=>\%shipment_properties,
						},
					'order/payment'=>{
						'date_detection' => 'false',
						'dynamic'=>'false',
						'_parent'=>{ 'type'=>'order', },
						'properties'=>\%payment_properties,
						},
					'order/item'=>{
						'date_detection' => 'false',
						'dynamic'=>'strict',
						'_parent'=>{ 'type'=>'order' },
						'properties'=>\%item_properties,
						},	
					},
				'settings'=>{
					analysis => {
						analyzer => {
							#ascii_html => {
							#	type => 'custom',
							#	tokenizer => 'standard',
							#	filter => [ qw( standard lowercase asciifolding stop ) ],
							#	char_filter => ['html_strip'],
							#	},
							default => {
 								tokenizer	=> 'standard',
								char_filter => ['html_strip'],
								filter		=> [qw(standard lowercase stop asciifolding)],
								},
							'lcKeyword' => {
								'tokenizer' => 'keyword',
								'filter' => [ 'asciifolding', 'lowercase' ],
								},
							'urlemail' => {
								'tokenizer' => 'uax_url_email',
								},
							}
						}
					}
				}
			);
		}

#	my ($es) = $options{'*es'};
#	if (not defined $es) { $es = &ZOOVY::getElasticSearch($USERNAME); }
#	

	if (not defined $options{'CREATED_GMT'}) {
		$options{'CREATED_GMT'} = (time() - 86400*365); # &ZTOOLKIT::mysql_to_unixtime("20121201000000");
		}

	require ORDER::BATCH;
	my ($r) = ORDER::BATCH::report($USERNAME,%options);
	foreach my $set (@{$r}) {
		# next unless ($set->{'ORDERID'} eq '2013-10-1063');
		my ($c2) = CART2->new_from_oid($USERNAME,$set->{'ORDERID'});
		next if (not defined $c2);
		$c2->elastic_index('*es'=>$es);
		}

	}


##
##
##
sub rebuild_product_index {
	my ($USERNAME,%options) = @_;

	my $ESINDEX = lc("$USERNAME.public");

	my %NC_PROPERTIES = ();
	$NC_PROPERTIES{'path'} = { 'buffer_size'=>128, 'type'=>'string',  'analyzer'=>'lcKeyword', 'include_in_all'=>0 };
	$NC_PROPERTIES{'pid'} = { 'store'=>'yes', 'type'=>'string',  'analyzer'=>'lcKeyword', 'include_in_all'=>1 };
	$NC_PROPERTIES{'prt'} = { 'type'=>'integer', 'include_in_all'=>0, };
	#$NC_PROPERTIES{'thumbnail'} = { 'type'=>'string',  'analyzer'=>'lcKeyword', 'include_in_all'=>0 };
	#$NC_PROPERTIES{'keywords'} = { 'buffer_size'=>20, 'type'=>'string',  'analyzer'=>'lcKeyword', 'include_in_all'=>0 };
	#$NC_PROPERTIES{'tags'} = { 'type'=>'string', 'analyzer'=>'lcKeyword', 'include_in_all'=>1 };
	#$NC_PROPERTIES{'breadcrumbs'} = { 'buffer_size'=>128, 'type'=>'string',  'analyzer'=>'lcKeyword', 'include_in_all'=>0 };
	#$NC_PROPERTIES{'hidden'} = { 'type'=>'boolean', 'include_in_all'=>0, };

	## special index fields:
	## list of analyzers
	## www.elasticsearch.org/guide/reference/index-modules/analysis/snowball-tokenfilter.html
	## NOTE: keyword is case sensitive
	my %SKU_PROPERTIES = ();
	$SKU_PROPERTIES{'pid'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };
	$SKU_PROPERTIES{'sku'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>35, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };
	$SKU_PROPERTIES{'ts'} = { 'type'=>'integer', 'include_in_all'=>0 };
	$SKU_PROPERTIES{'available'} = { 'type'=>'integer', 'include_in_all'=>0 };
	$SKU_PROPERTIES{'markets'} = { 'type'=>'integer', 'include_in_all'=>0 };
	$SKU_PROPERTIES{'onshelf'} = { 'type'=>'integer', 'include_in_all'=>0 };
	$SKU_PROPERTIES{'dirty'} = { 'type'=>'boolean', 'include_in_all'=>0 };

	my %PRODUCT_PROPERTIES = ();
	$PRODUCT_PROPERTIES{'pid'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };
	$PRODUCT_PROPERTIES{'skus'} = { 'analyzer'=>'lcKeyword',  'buffer_size'=>35, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'options'} = { 'analyzer'=>'lcKeyword', 'type'=>'string', 'store'=>'no', 'include_in_all'=>'no' };
	$PRODUCT_PROPERTIES{'pogs'} = { 'analyzer'=>'keyword',  'buffer_size'=>6, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'tags'} = { 'analyzer'=>'keyword',  'buffer_size'=>15, 'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'images'} = { 'analyzer'=>'keyword',  'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'child_pids'} = { 'analyzer'=>'lcKeyword',  'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'assembly_pids'} = { 'analyzer'=>'lcKeyword',  'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	$PRODUCT_PROPERTIES{'marketplaces'} = { 'analyzer'=>'lcKeyword',  'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };
	# $PRODUCT_PROPERTIES{'breadcrumbs'} = { 'analyzer'=>'lcKeyword',  'type'=>'string', 'store'=>'no', 'include_in_all'=>0 };

#	my %INVSUMMARY_PROPERTIES = ();	
#	$PRODUCT_PROPERTIES{'pid'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>20, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };
#	$PRODUCT_PROPERTIES{'sku'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>35, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };
#	$PRODUCT_PROPERTIES{'sku'} = { 'analyzer'=>'lcKeyword',   'buffer_size'=>35, 'type'=>'string', 'store'=>'no', 'include_in_all'=>1 };


	my @INDEXABLE_FIELDS = ();

#	print 'USER:'.Dumper(&PRODUCT::FLEXEDIT::userfields($USERNAME));
#	print Dumper(&PRODUCT::FLEXEDIT::allfields($USERNAME));
	my @IMAGES = ();
	my ($FIELDSREF,$IMAGE_FIELDSREF) = &PRODUCT::FLEXEDIT::elastic_fields($USERNAME,'gref'=>$options{'gref'});

	## load system wide fields that everybody gets
	foreach my $id (keys %PRODUCT::FLEXEDIT::fields) {
		next if ($PRODUCT::FLEXEDIT::fields{$id}->{'ns'} eq 'profile');
		# print "ID: $id\n";
		my $fref = undef;
		if (defined $PRODUCT::FLEXEDIT::fields{$id}->{'index'}) {
 			$fref = Clone::clone($PRODUCT::FLEXEDIT::fields{$id});
			$fref->{'id'} = $id;
			push @INDEXABLE_FIELDS, { 'id'=>$fref->{'id'}, 'type'=>$fref->{'type'}, 'index'=>$fref->{'index'} };
			}
		elsif ($id =~ /^(zoovy|amz|ebay)\:prod_image/) {
			## skip "known" image fields to reduce global.bin size
			}
		elsif ($PRODUCT::FLEXEDIT::fields{$id}->{'type'} eq 'image') {
			# push @INDEXABLE_FIELDS, { 'id'=>$id, 'type'=>'image', 'index'=>'images' };
			push @IMAGES, $id;
			}

		# print 'BEFORE: '.Dumper($fref);
		next if (not defined $fref);		## this $fref doesn't need a specific type (already added to $PRODUCT_PROPERTIES)
		}

	## load custom user fields
	foreach my $fref (@{$FIELDSREF}) {
		next if ($fref->{'ns'} eq 'profile');
		# print "ID: $id\n";
		if (defined $fref->{'index'}) {
 			$fref = Clone::clone($fref);
			push @INDEXABLE_FIELDS, $fref;
			}
		}

	## Format the user fields.
	foreach my $fref (@INDEXABLE_FIELDS) {
		my %F = ();
		$F{'type'} =  'string'; 
		$F{'store'} = 'yes'; 
		$F{'include_in_all'} = 1;

		if ($fref->{'elastic'}) {
			## load special elastic = type settings
			my $params = &ZTOOLKIT::parseparams($fref->{'elastic'});
			foreach my $k (keys %{$params}) {
				if ($k eq 'preset') {
					## preset is special, it lets us load a whole bunch of "sane" values for elastic that we use all over the place
					## e.g. keyword, currency, finder
					$fref->{'type'} = $params->{$k};
					}
				else {
					$fref->{$k} = $params->{$k};
					}
				}
			}

		$PRODUCT_PROPERTIES{$fref->{'index'}} = \%F;
		if ($fref->{'index'} eq '') {
			}
		elsif ($fref->{'sku'}) {
			$SKU_PROPERTIES{$fref->{'index'}} = \%F;
			}

		if ($fref->{'type'} =~ /^(asin|profile|upc|isbn|reference)$/) {
			## asin,profile,upc,etc. are all just keywords (aka fixed values which don't need relevancy)
			$fref->{'type'} = 'keyword';
			}
		

		## http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
		if ($fref->{'type'} eq 'finder') {
			## finders are lists of products ex. related_products, accessory_products
			$F{'type'} = 'string';
			$F{'index'} = 'analyzed';
			$F{'include_in_all'} = 0;
			$F{'analyzer'} = 'keyword';
			}
		elsif ($fref->{'type'} =~ /^(textarea|textbox|text|readonly)$/) {
			## splits on spaces and punctuation, analyzes and *should* return on relevance
			$F{'type'} =  'string'; 
			$F{'index'} =  'analyzed';
			$F{'analyzer'} = 'default';

			if ($fref->{'id'} eq 'zoovy:prod_name') {
				## http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
				## in elasticsearch it's not possible to SORT based on an indexed (tokenized field) ex: prod_name  (because lucene/es will sort by the least/most significant token)
				## I *think* a while ago (at least in the code) we had implemented multiple keys - specifically "prod_name.untouched" to work around this limitation, or maybe as a proof of concept.  
				## Anyway I want to change prod_name.untouched to prod_name.xxx (not sure yet) but don't want to break anything.
				## Let me know if you can recall using prod_name.untouched (to sort by prod_name) in any of your previous projects.
				delete $F{'index'};
				$F{'type'} = 'multi_field';
				$F{'fields'} = {
					'prod_name' => {"type" => "string", "index" => "analyzed"},
					# prod_name.raw
					'raw' => {"type" => "string", "index" => "not_analyzed",  "analyzer" => "naturalsort" },
					};
				}

			}
		elsif (($fref->{'type'} eq 'keyword') || ($fref->{'type'} eq 'keywordlist') || ($fref->{'type'} eq 'commalist')) {
			$F{'type'} =  'string'; 
			$F{'analyzer'} = 'lcKeyword';
			}
		elsif ($fref->{'type'} eq 'select') {
			$F{'type'} =  'string'; 
			$F{'analyzer'} = 'lcKeyword';
			}
		elsif ($fref->{'type'} eq 'image') {
			$F{'type'} =  'string'; 
			$F{'analyzer'} = 'lcKeyword';
			}
		elsif ($fref->{'type'} eq 'currency') {
			## currency is never stored as a floating point
			$F{'type'} = 'long';
			$F{'include_in_all'} = 0;
			$F{'index'} = 'not_analyzed'; 
			$F{'null_value'} = 0;
			$F{'ignore_malformed'} = 'true';
			$F{'store'} = 'true';
			## $F{'index'} = 'yes';
			## short,integer,float
			}
		elsif (($fref->{'type'} eq 'number') || ($fref->{'type'} eq 'integer')) {
			$F{'type'} = 'integer';
			if ($fref->{'type'} eq 'number') { $F{'type'} = 'long'; }
			$F{'include_in_all'} = 0;
			## $F{'index'} = 'not_analyzed';
			$F{'null_value'} = 0;
			}
		elsif (($fref->{'type'} eq 'checkbox') || ($fref->{'type'} eq 'boolean')) {
			$F{'type'} = 'boolean';
			$F{'include_in_all'} = 0;
			}
		elsif ($fref->{'type'} eq 'weight') {
			$F{'type'} = 'integer';
			$F{'include_in_all'} = 0;
			}
		elsif ($fref-{'type'} eq 'hash:currency') {
			## used for sku:pricetags, but it can be ignored.
			}
		## NOTE: these types are implicitly added later in the code, and don't need to be handled here:
		#elsif ($fref->{'type'} eq 'image') {
		#	push @IMAGE_FIELDS, $fref->{'id'};
		#	}
		#elsif ($fref->{'type'} eq 'constant') {
		#	# prod_is
		#    $F{'type'} = 'string';
		#    $F{'index'} = 'analyzed';
		#    $F{'include_in_all'} = 0;
		#    $F{'analyzer'} = 'keyword';
 		#	}
		else {
			warn "UNKNOWN TYPE: ".Dumper($fref);
			# die();
			}

		#print Dumper($fref,\%P);
		}

	#print Dumper(\%PRODUCT_PROPERTIES);
	# print Dumper(\@INDEXABLE_FIELDS);
	
	my @SYNONYMS = ();
	# blank lines and lines starting with pound are comments.

	#Explicit mappings match any token sequence on the LHS of "=>"
	#and replace with all alternatives on the RHS.  These types of mappings
	#ignore the expand parameter in the schema.
	#Examples:
	#i-pod, i pod => ipod,
	#sea biscuit, sea biscit => seabiscuit

	#Equivalent synonyms may be separated with commas and give
	#no explicit mapping.  In this case the mapping behavior will
	#be taken from the expand parameter in the schema.  This allows
	#the same synonym file to be used in different synonym handling strategies.
	#Examples:
	#ipod, i-pod, i pod
	#foozball , foosball
	#universe , cosmos

	# If expand==true, "ipod, i-pod, i pod" is equivalent to the explicit mapping:
	#ipod, i-pod, i pod => ipod, i-pod, i pod
	# If expand==false, "ipod, i-pod, i pod" is equivalent to the explicit mapping:
	#ipod, i-pod, i pod => ipod

	#multiple synonym mapping entries are merged.
	#foo => foo bar
	#foo => baz
	#is equivalent to
	#foo => foo bar, baz	


	# my $PATH_ON_CLUSTER = sprintf("/data/users/%s/%s",lc(substr($USERNAME,0,1)),lc($USERNAME));
	my $PATH_ON_CLUSTER = sprintf("/users/%s",lc($USERNAME));

	my $HAS_STOPWORDS = (-f &ZOOVY::resolve_userpath($USERNAME).'/elasticsearch-product-stopwords.txt')?1:0;
	my $HAS_SYNONYMS = (-f &ZOOVY::resolve_userpath($USERNAME).'/elasticsearch-product-synonyms.txt')?1:0;
	my $HAS_CHARMAP = (-f &ZOOVY::resolve_userpath($USERNAME).'/elasticsearch-product-charactermap.txt')?1:0;

	my %FILTERS = ();
	my %CHAR_FILTERS = ();
	if ($HAS_STOPWORDS) {
		$FILTERS{'useStopWords'} = {
						'type'=>'stop',
						#'stopwords'=>\@STOPWORDS,
						'stopwords_path'=>"$PATH_ON_CLUSTER/elasticsearch-product-stopwords.txt",
						'ignore_case'=>'true',
						'enable_position_increments'=>'true'
						};
		}
	if ($HAS_SYNONYMS) {
		$FILTERS{'synonym'} = {
						'type' => 'synonym',
					#	'synonyms' => \@SYNONYMS,
						'synonyms_path'=>"$PATH_ON_CLUSTER/elasticsearch-product-synonyms.txt",
					#	 'synonyms_path' => 'analysis/synonym.txt'
					#	 'synonyms' => [
					#		 'i-pod, i pod => ipod',
					#		 'universe, cosmos'
					#		] 
						};
		}

	if ($HAS_CHARMAP) {
		$CHAR_FILTERS{"my_mapping"} = {
			"type" => "mapping",
			# "mappings" : ["ph=>f", "qu=>q"]
			'mappings_path' => "$PATH_ON_CLUSTER/elasticsearch-product-charactermap.txt",
			};
		}


	my %public = (
		'index' => lc($ESINDEX),
		'mappings' => { 
			'product' => {
				'properties'=>\%PRODUCT_PROPERTIES
				},
			'sku'=> {
				'_parent'=>{ 'type' => 'product' },
				# '_routing'=>{ 'required'=>'false', 'path'=>'product.pid' },
				'properties'=>\%SKU_PROPERTIES,
				},
			'navcat'=> {
				'_parent'=>{ 'type' => 'product' },
				# '_routing'=>{ 'required'=>'false', 'path' => 'product.pid '},
				'properties'=>\%NC_PROPERTIES,
				},
			},
		'settings'=>{
			'number_of_shards' => 1,
			'analysis' => {
				# www.elasticsearch.org/guide/reference/index-modules/analysis/mapping-charfilter.html
				"char_filter" => \%CHAR_FILTERS,
				'analyzer' => {
					#ascii_html => {
					#	type => 'custom',
					#	tokenizer => 'standard',
					#	filter => [ qw( standard lowercase asciifolding stop ) ],
					#	char_filter => ['html_strip'],
					#	},
					'default' => {
 						'tokenizer'	=> 'standard',
						'char_filter' => ['html_strip',(($HAS_CHARMAP)?'my_mapping':undef) ],
						'filter'		=> ['standard', 'lowercase', ($HAS_SYNONYMS?'synonym':undef), ($HAS_STOPWORDS?'useStopWords':undef), 'stop', 'asciifolding'],
						},
 					'lcKeyword' => {
						'tokenizer' => 'keyword',
						'filter' => [ 'asciifolding', 'lowercase', 'stop'  ],
						},
					'synonym' => {
						'tokenizer' => 'whitespace',
						'filter' => [ ($HAS_SYNONYMS?'synonym':undef) ]
						},
					'naturalsort' => {
						'tokenizer' => 'keyword',
						'filter' => [ 'lowercase', 'asciifolding' ],
						'char_filter' => [ 'html_strip' ]
						},
					},
				'filter' => \%FILTERS,
				}
			}
		);

	# www.elasticsearch.org/guide/reference/mapping/array-type.html
 	# www.elasticsearch.org/guide/reference/index-modules/analysis/
	# www.elasticsearch.org/guide/reference/mapping/object-type.html
	# www.elasticsearch.org/guide/reference/mapping/core-types.html
	if ((defined $options{'schemaonly'}) && ($options{'schemaonly'})) {
		}
	else {
		my ($es) = &ZOOVY::getElasticSearch($USERNAME);
		if ($es->indices->exists("index"=>$ESINDEX)) {
			$es->indices->delete("index"=>$ESINDEX);
			}

		## curl -XGET 'http://127.0.0.1:9200/my_index/_mapping?pretty=1' 
		my ($result) = $es->indices->create('index'=>$ESINDEX,'body'=>\%public);
		open F, ">".&ZOOVY::resolve_userpath($USERNAME)."/public-index.dmp";
		print F Dumper(\%public);
		close F;
	
		my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
		my $changed++;
		if (not defined $globalref->{'%elastic'}) {
			$globalref->{'%elastic'} = {};
			}
		$globalref->{'%elastic'}->{'@product.images'} = [];
		$globalref->{'%elastic'}->{'@product.fields'} = [];

		## let's always make sure we're working with the latest product set
		$ZOOVY::GLOBAL_CACHE_FLUSH = 1;
		&ZOOVY::nuke_product_cache($USERNAME);
		my @pids = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);
		foreach my $b (@{&ZTOOLKIT::batchify(\@pids,150)}) {
			# print Dumper($b);
			my ($Prodrefs) = &PRODUCT::group_into_hashref($USERNAME,$b);
			delete $Prodrefs->{''};	## no blank PID's
			my @Prods = values %{$Prodrefs};

			&ELASTIC::add_products($USERNAME,\@Prods, '*es'=>$es,'index'=>$ESINDEX, 'gref'=>$globalref);
			}

		open F, ">/tmp/payloads";
		print F Dumper(\@ELASTIC::ES_PAYLOADS);
		close F;		

		my ($bulk) = Elasticsearch::Bulk->new('es'=>$es,'index'=>$ESINDEX);
		foreach my $PRT (&ZWEBSITE::prts($USERNAME)) {
			my ($NC) = NAVCAT->new($USERNAME,'PRT'=>$PRT);
			foreach my $payload (@{$NC->elastic_payloads()}) {
				$payload->{'source'} = $payload->{'doc'}; delete $payload->{'doc'};
				$bulk->index($payload)				
				}
			}
		$bulk->flush();
		
		$globalref->{'%elastic'}->{'product.created_gmt'} = time();
		&ZWEBSITE::save_globalref($USERNAME,$globalref);
		}

	## do navcats here.

	return(\%public);
	}







1;

