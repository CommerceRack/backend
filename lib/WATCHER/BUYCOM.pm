package WATCHER::BUYCOM;

use strict;

# http://www.buy.com/pr/SellerListings.aspx?sku=205626500&pg=1
#[8:34:46 AM] Jamie Harkins: http://www.buy.com/pr/SellerListings.aspx?sku=205626500&pg=1
#[8:46:55 AM] Brian Horakh: http://www.buy.com/pr/SellerListings.aspx?sku=217144605&pg=1

use Data::Dumper;
use LWP::UserAgent;
use HTML::Parser;

use lib "/backend/lib";
require ZOOVY;
require SYNDICATION;
require XMLTOOLS;
require ZTOOLKIT;
require AMAZON3;


sub verify {
	my ($w,$SKU,$BUYSKU) = @_;

	my ($ERROR,$HTML,@ELEMENTS) = (undef,undef,());
	
	if (not defined $ERROR) {
		if ($BUYSKU eq '') { $ERROR = 'Product BuyCom SKU not set'; }
		elsif ($SKU eq '') { $ERROR = 'Product SKU not set'; }
		}

	if (1) {
		open F, "</tmp/foo";
		while (<F>) { $HTML .= $_; }
		close F;
		}
	elsif (not defined $ERROR) {
		## phase1: get the html
		my $URL = "http://www.buy.com/pr/SellerListings.aspx?sku=$BUYSKU&pg=1";
		($ERROR,$HTML) = $w->get($URL);
		open F, ">/tmp/foo";
		print F $HTML;
		close F;
		}	

	print "ERROR: $ERROR\n";

	if (not defined $ERROR) {
		## phase2: parse it.
		(@ELEMENTS) = @{&scrape($HTML)};
		if (scalar(@ELEMENTS)==0) {
			## this means nobody is selling the product
			$ERROR = "No valid pricing elements found during scrape (product is not for sale!?)";
			}
		}
	print Dumper(\@ELEMENTS);

	
	}



## 
## this function parses through the html and returns an array of prices
##		[
##		{
##		'price'=>'','shipping'=>'',
##		'rating'=>'',
##		'instock'=>1|0,expedited=>1|0,
##		'ratings'=>####,
##		'condition'=>'New',
##		'sellerid'=>'15digitamazonid',
##		'seller'=>'Case Sensitive Merchant Name',
##		'errors'=>1	# if an error was encountered
##		'is_fba'=>1,	#self explanatory
##		}
##		]
##	
##	if an error is encountered during parsing the following fields might be set:
##		error=>1|0
##		_tagreference -- (these are normally discarded, but if we have an error we keep them around for diagnostics)
##		@missing=>[ 'seller','sellerid' ] -- this will be set if one or more required attributes are missing
##
sub scrape {
	my ($HTML) = @_;

	my $ERROR = undef;
	my @ELEMENTS = ();

#	use Marpa::HTML;
#	my $result = Marpa::HTML::html(\$HTML);
	
	use HTML::TreeBuilder;
	my $tree = HTML::TreeBuilder->new; # empty tree
	my $result = $tree->parse($HTML);

	## the rows for each seller seem to appear within a div class="resultsset"
	## sl-main-table
	## sl-td-pricing-sec
	my ($divSellerListings) = $tree->look_down('id','divSellerListings');
	my ($sl_main_table) = $divSellerListings->look_down("class","sl-main-table");

	my @trs = $sl_main_table->look_down('_tag','tr');
	my $i = 0;
	foreach my $tr (@trs) {
		next unless ($tr->look_down('class','sl-td-pricing-sec'));
		print "--------------\n";
		print $tr->as_HTML();
		# next if ($tr->look_down('_tag','th'));
		# <div id="af-div"
		# next if ($tr->look_down('id','af-div'));

		my %info = ();
		$info{'+'} = $i;
		my $v = undef;	# just a temp variable.

		# <span class="price">$149.15</span>
		# <span class="price">$999.00</span>
		$v = $tr->look_down('class','price');
		if ($v) { $info{'price'} = $v->as_text(); }
		if (defined $info{'price'}) {	
			$info{'price'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
			}

		# rptBoxListings_ctl00_divMPListingShipping
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_divMPListingShipping",$i));
		if ($v) { $info{'shipping'} = $v->as_text(); }
		if (defined $info{'shipping'}) {	
			$info{'shipping'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
			}

		# "rptBoxListings_ctl00_divMPTotal"
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_divMPTotal",$i));
		if ($v) { $info{'deliveredprice'} = $v->as_text(); }
		if (defined $info{'deliveredprice'}) {	
			$info{'deliveredprice'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
			}
	


		# "rptBoxListings_ctl00_divMPCondition"
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_divMPCondition",$i));
		if ($v) { 
			$info{'condition'} = $v->as_text(); 
			## $info{'condition'} == *Brand New  === the * means it has notes/comments
			$info{'condition'} =~ s/^\*//gs;	# strip leading *
			}

		# id="rptBoxListings_ctl00_anchorMPListingLink"
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_anchorMPListingLink",$i));
		if ($v) { $info{'seller'} = $v->as_text(); }

	   # <span id="rptBoxListings_ctl00_spanTotalReviews" class="number">4.38 stars over the past 12 months (<a href="http://www.buy.com/listing/sellersummary.asp?sellerID=21502499&sku=205626500&loc=64935&buy=0&c=1" class="blueText">125 ratings</a>). 132 total ratings.</span>
		# <li class="active"><span id="rptBoxListings_ctl00_reviewerRating" class="s45"></span></li>
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_spanTotalReviews",$i));
		if ($v) { 
			$info{'rating_pretty'} = $v->as_text();
			if ($info{'rating_pretty'} =~ /^([\d\.]+) /) {
				# 4.38 stars 
				$info{'stars'} = $1;
				}
			if ($info{'rating_pretty'} =~ /\(([\d]+) ratings\)\./) {
				#  (23 ratings).
				$info{'ratings_recent'} = $1;
				}
			if ($info{'rating_pretty'} =~ /([\d]+) total ratings\./) {
				# 24 total ratings.
				$info{'ratings_total'} = $1;
				}
			if ($v->as_HTML() =~ /sellerID\=([\d]+)\&/) {
				$info{'sellerid'} = int($1); 
				}
			}

		if ((not defined $info{'sellerid'}) || ($info{'sellerid'}==0)) {
			## just in case, a backup way to get sellerid
			if ($tr->as_HTML() =~ /sellerID\=([\d]+)\&/) {
            $info{'sellerid'} = int($1);
            }
			}
		
		# <div id="rptBoxListings_ctl06_divNewSeller">
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_divNewSeller",$i));
		if ($v) {
			$info{'rating_pretty'} = 'New Seller';
			$info{'is_new'} = 1;
			}
		
		# <a href="http://www.buy.com/listing/sellersummary.asp?sellerID=21502499&sku=205626500&loc=64935&buy=0&c=1" id="rptBoxListings_ctl00_anchorMPShippingRates" class="blueText" style="font-size:11px;">See shipping rates</a>

		# <a href="http://buycostumes.store.buy.com/" id="rptBoxListings_ctl00_viewMyStore"><img src="http://ak.buy.com/buy_assets/marketplace/mp_visitstore_med.gif" id="rptBoxListings_ctl00_imgViewMyStore" border="0" align="absmiddle" alt="View My Store" /></a>
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_viewMyStore",$i));
		if ($v) {
			$info{'has_store'}++;
			}

		# <div id="rptBoxListings_ctl00_divMPComments"><b>*Comments:</b> Pirates of the Caribbean - Jack Sparrow Pirate Hat With Beaded Braids</div>
		($v) = $tr->look_down('id',sprintf("rptBoxListings_ctl%02d_divMPComments",$i));
		if ($v) {
			$info{'comments'} = $v->as_text();
			}

		push @ELEMENTS, \%info;
		$i++;
		}

	return(\@ELEMENTS);
	}	


__DATA__
			my %info = ();		## is the hash we're going to return about this particular seller
									## we'll push this onto @ELEMENTS later.


			## _tr starts with a _ which means it's a debug key, it will be discarded (for readability) if no errors are encountered
			##	however if an error is found - then it will be preserved (for posterity)
			$info{'_tr'} = $tr->as_HTML();

			next;


			my $v = undef;	# just a temp variable.

			# <span class="price">$149.15</span>
			# <span class="price">$999.00</span>
			$v = $tr->look_down('class','price');
			if ($v) { $info{'price'} = $v->as_text(); }
			if (defined $info{'price'}) {	
				$info{'price'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
				}

			# <span class="price_shipping">+ $0.00</span>
			$v = $tr->look_down('class','price_shipping'); 
			if ($v) { $info{'shipping'} = $v->as_text(); }
			if (defined $info{'shipping'}) {	
				$info{'shipping'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
				}

			# <b>94% positive</b>
			if ($tr->as_HTML() =~ /<b>([\d]+)% positive\<\/b\>/) { 
				$info{'rating'} = $1; 
				}
			# <span class="justlaunched"> Just Launched</span>
			elsif ((not defined $info{'rating'}) && ($v = $tr->look_down('class','justlaunched'))) {
				$info{'is_justlaunched'}++;
				$info{'rating'} = 0;
				}

			# <div class="availability">
			$v = $tr->look_down('class','availability');
			if ($v) {
				$info{'_availability'} = $v->as_HTML();
				if ($info{'_availability'} =~ /Usually ships within 1 \- 3 weeks/) { $info{'instock'} = 0; }
				if ($info{'_availability'} =~ /In Stock./) { $info{'instock'} = 1; }
				if ($info{'_availability'} =~ /Expedited/) { $info{'expedited'} = 1; }
				# (7,066 total ratings)
				if ($info{'_availability'} =~ /\(([\d,]+) total ratings\)/) { $info{'ratings'} = $1; }
				# <a href="/gp/help/seller/shipping.html/ref=olp_merch_ship_10/180-5621601-3754528?ie=UTF8&amp;asin=B003L7X9O8&amp;seller=AA8YLSTZM38ZI"
				if ($info{'_availability'} =~ /seller\=(.*?)[\"\&]+/) { $info{'sellerid'} = $1; }
				}

			# <span class="ratingHeader">Seller Rating:</span>
			# <img alt="" border="0" height="12" src="http://g-ecx.images-amazon.com/images/G/01/detail/stars-4-5._V192261415_.gif" width="64" />
			# <a href="/gp/help/seller/at-a-glance.html/ref=olp_merch_rating_1/181-4322936-2570247?ie=UTF8&amp;isAmazonFulfilled=1&amp;asin=B001DHHPYI&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR" id="rating_-ic0FuuTF1-WCaIi71wGoi3fhKGHqmO0dHaIc-HIGwmtqWDZ7wkwItgevvqZNkXJ9VTqKFRQSvB2nFlUZ3GJ7RiVZ4tgcAA5NClMSQ-QsDuOKEnsccv1SxOVLRZIihw2m8KIn71YdPFX1-SLYJi9-A--" onclick="return amz_js_PopWin(&#39;/gp/help/seller/at-a-glance.html//ref=olp_merch_rating_1/181-4322936-2570247?ie=UTF8&amp;isAmazonFulfilled=1&amp;asin=B001DHHPYI&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR&#39;, &#39;OLPSellerRating&#39;, &#39;width=1000,height=600,resizable=0,scrollbars=1,toolbar=0,status=0&#39;);"><b>92% positive</b></a> over the past 12 months. (10,463 total ratings)</div><li><div class="availability"> In Stock. <span id="ftm_%2Fic0FuuTF1%2FWCaIi71wGoi3fhKGHqmO0dHaIc%2FHIGwmtqWDZ7wkwItgevvqZNkXJ9VTqKFRQSvB2nFlUZ3GJ7RiVZ4tgcAA5NClMSQ%2FQsDuOKEnsccv1SxOVLRZIihw2m8KIn71YdPFX1%2BSLYJi9%2FA%3D%3D">
			if ($v = $tr->look_down('class','sellerInformation')) {
				$info{'_sellerInformation'} = $v->as_HTML();
				if ($info{'_sellerInformation'} =~ /\&amp\;seller\=(.*?)\"/) { $info{'sellerid'} = $1; }
				}



			# <div class="condition">New </div>
			$v = $tr->look_down('class','condition');
			if ($v) {
				$info{'condition'} = $v->as_text();
				$info{'condition'} =~ s/[\n\r\s]+$//gs;
				}

			if ($info{'sellerid'} eq 'ATVPDKIKX0DER') {
				## amazon prime tm
				$info{'is_fba'}++;
				}
		
			# <div class="fba_link" style="margin-top:8px; margin-left:0px;">
			if ($tr->look_down('class','fba_link')) {
				$info{'is_fba'}++;
				}

			if ($info{'is_fba'}) {
				$info{'expedited'} = 1;
				$info{'rating'} = 100;
				if ($tr->look_down('class','supersaver')) {
					$info{'shipping'} = -0.01;
					}
				# $info{'_debug'}++;		# (if we set _debug then all debug tags (start with _) will be preserved even if no error was found)
				}

			if ($info{'seller'} ne '') {
				## wtf, already set seller name -- not sure how this happened.
				}
			elsif ($v = $tr->look_down('class','seller')) {
				## some sellers don't have a graphic, so we have to search this way:
				# <div class="seller"><span class="sellerHeader">Seller:</span> 
				# <a href="/gp/help/seller/at-a-glance.html/ref=olp_merch_name_3/191-2761299-2589101?ie=UTF8&amp;isAmazonFulfilled=0&amp;asin=B002FH5QJQ&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR">
				# <b>Martial Arts Land</b></a> </div>
				$info{'seller'} = $v->as_text();
				# "Seller: Martial Arts Land ";
				$info{'seller'} =~ s/^Seller:[\s]+//gs;
				$info{'seller'} =~ s/[\n\s\r]+$//gs;	# not necessary, but just in case.
				# $info{'_debug'}++;
				}
			elsif ($v = $tr->look_down('_tag','img')) { 
				# <img alt="FramesExperts" border="0" height="30" src="http://ecx.images-amazon.com/images/I/51piq-1yfhL.jpg" width="120" />
				$info{'seller'} = $v->as_HTML(); 
				if ($info{'seller'} =~ /alt="(.*?)"/) { $info{'seller'} = $1; }
				}

			push @ELEMENTS, \%info;
			# print $tr->as_HTML()."\n";
			#print Dumper(\%info);
			#print "\n-------\n";
			}		
		}

	# print Dumper(\@ELEMENTS);

	## an array of %info nodes.		
	return(\@ELEMENTS);
	}




1;