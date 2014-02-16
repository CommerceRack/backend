package PAGE::DATAEXPORT;

use strict;
use Text::CSV_XS;
use Tie::Hash::Indexed;
use lib '/backend/lib';
require ZTOOLKIT;
require NAVCAT;
require WHOLESALE;
require INVENTORY2;

sub handle {
	my ($SITE, $SENDER) = @_;

	my ($NC) = $SITE->get_navcats();
	#my ($NC) = NAVCAT->new($SITE::merchant_id);
	#use Data::Dumper; print STDERR Dumper($NC);
	my ($pretty,$children,$products,$sort,$metaref) = $NC->get('.');
	# @products = split(/,/,$products);
	#$NC = undef;

	my ($C) = $SITE->cart2()->customer();

	if (not defined $C) {
		print "Not logged in.\n";
		return();
		}

	my $SCHEDULE = '';

	$SCHEDULE = $SITE->cart2()->in_get('our/schedule');
	my $is_wholesale = $SITE->cart2()->in_get('is/wholesale');
	if (($is_wholesale & 2)==0) {
		print "No access to this feature.\n";
		return();
		}

	my $csv = Text::CSV_XS->new({ binary => 1 });
	my ($FILE,$TYPE) = split(/\./,uc($SENDER));
	if ($TYPE eq 'XML') { $TYPE = 1; }
	elsif ($TYPE eq 'CSV') { $TYPE = 2; }
	else { $TYPE = 0; }


	#print STDERR "[DATAEXPORT] FILE: $FILE TYPE: $TYPE SENDER: $SENDER\n";
	my $BODY = '';
	if ($TYPE==1) {
		$BODY .= "<?xml version=\"1.0\"?>\n");
		}

	# print "SENDER: $SITE::merchant_id  [$FILE][$TYPE]\n";
	tie my %columns, 'Tie::Hash::Indexed';

	if ($FILE eq 'PRODUCTS') {
		if ($TYPE==1) { $BODY .= "<products>"); }
		if ($TYPE==2) { $BODY .= "PID,TITLE,PRICE,MSRP,IMAGEURL,DESCRIPTION,SHIP_COST\n"); }

		## changed to use okay_to_show - patti - 2008-05-21
		## takes into account the profile for the site, hidden categories
		## 	if products are in-stock		
		# my ($NC) = NAVCAT->new($SITE::merchant_id);
		my $ref = $NC->okay_to_show($SITE->username(),undef,$SITE->rootcat());
		#my ($ref) = ZOOVY::fetchproducts_by_nameref($SITE::merchant_id);

		my @pids = keys %{$ref};
		my $prodsref = &PRODUCT::group_into_hashref($SITE->username(),\@pids);
		
		foreach my $P (values %{$prodsref}) {
			## added tweak_product - patti - 2008-05-21
			$P->wholesale_tweak_product($SCHEDULE);
			
			# my $image = &IMGLIB::Lite::url_to_image($SITE->username(),$P->fetch('zoovy:prod_image1'),0,0,'',0,$SITE::SREF->{'+cache'},0);
			my $image = sprintf("http://www.%s%s",$SITE->domain_only(),&ZOOVY::image_path($SITE->username(), $P->fetch('zoovy:prod_image1')));
			
			## this is an ordered hash!
			
			if ($TYPE==2) {
				my @cols = ();
				push @cols, $P->pid();
				push @cols, $P->fetch('zoovy:prod_name');
				push @cols, $P->fetch('zoovy:base_price');
				push @cols, $P->fetch('zoovy:prod_msrp');
				push @cols, $image;
				push @cols, $P->fetch('zoovy:prod_desc');
				push @cols, $P->fetch('zoovy:ship_cost1');
				my $status = $csv->combine(@cols);    # combine columns into a string
				$BODY .= "\r\n".$csv->string());               # get the combined string
				}
			else {
				%columns = ( 
					'pid'=>$P->pid(), 
					'title'=>$P->fetch('zoovy:prod_name'),
					'price'=>$P->fetch('zoovy:base_price'),
					'msrp'=>$P->fetch('zoovy:prod_msrp'),
					'imageurl'=>$image,
					'description'=>$P->fetch('zoovy:prod_desc'),
					'shipping'=>$P->fetch('zoovy:ship_cost1'),
					);
				$BODY .= &ZTOOLKIT::arrayref_to_xmlish_list([\%columns],
						tag=>'product'));
				}
			}

				
		if ($TYPE==1) { $BODY .= "</products>"); }
		}
	elsif ($FILE eq 'INVENTORY') {
		if ($TYPE==1) { $BODY .= "<inventory>"); }
		if ($TYPE==2) { $BODY .= "SKU,QTY,ONORDER\n"); }

		#my ($invref, $reserveref, $onorder) = &INVENTORY::load_records($SITE->username(),undef,8+16+128);	
		#use Data::Dumper;
		#print Dumper($invref);

		my ($INVSUMMARY) = INVENTORY2->new($SITE->username())->summary();
		foreach my $SKU (sort keys %{$INVSUMMARY}) {
			
			if ($TYPE==2) {
				my @cols = ();
				push @cols, $SKU;
				push @cols, $INVSUMMARY->{$SKU}->{'AVAILABLE'};
				push @cols, 0; # $onorder->{$sku};
				my $status = $csv->combine(@cols);    # combine columns into a string
				$BODY .= $csv->string()."\r\n");               # get the combined string
				}
			else {
				%columns = ( 'sku'=>$SKU, 'available'=>$INVSUMMARY->{$SKU}->{'AVAILABLE'}, 'onorder'=>0 );
				$BODY .= &ZTOOLKIT::arrayref_to_xmlish_list([\%columns],tag=>'inv'));
				}

			}

		if ($TYPE==1) { $BODY .= "</inventory>"); }
		}

	return($BODY);
	}


1;

