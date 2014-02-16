package PRODUCT::RSS;

use strict;
use Data::Dumper;
use Image::Magick qw();
use POSIX qw(strftime);
use XML::RSS;

use lib '/backend/lib';
require DOMAIN::TOOLS;
#require IMGLIB::Lite;
require ZOOVY;
require ZTOOLKIT;
require PRODUCT;
require SITE;


## create an RSS 1.0 file (http://purl.org/rss/1.0/)
## this is XML generator code from SITE/Static.pm
##
## my $xml = &PRODUCT::RSS::buildXML($USERNAME,\@PIDS,$ref);
##
sub buildXML {
	my ($USERNAME,$PIDS,$ref) = @_;
	
	my $NOWTS = time();
	my $CAMPAIGN = defined $ref->{'campaign'} ? $ref->{'campaign'} : '';
	my $CPGID = defined $ref->{'cpgid'} ? $ref->{'cpgid'} : 0;
	my $CREATEDGMT = defined $ref->{'createdgmt'} ? $ref->{'createdgmt'} : time();
	## my $PROFILE = defined $ref->{'profile'} ? $ref->{'profile'} : 'DEFAULT';
	my $SCHEDULE = (defined $ref->{'schedule'}) ? $ref->{'schedule'} : '';
	my $TRANSLATION = ($ref->{'translation'} ne '')?$ref->{'translation'} : 'LEGACYV1';
	# print STDERR "TRANSLATION: $TRANSLATION\n";

	my $SECUREKEY = undef;		
	if ($SCHEDULE ne '') {
		## SIGNATURE should *NEVER* be shown publically.
		require ZTOOLKIT::SECUREKEY;
		($SECUREKEY) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'RS');
		}
	my $SEC_REMAIN = defined $ref->{'sec_remain'} ? $ref->{'sec_remain'} : 3600;
	my $max_products = defined $ref->{'max_products'} ? $ref->{'max_products'} : 0;
	my $period = defined $ref->{'cycle_interval'} ? $ref->{'cycle_interval'}*60 : 0;
	
	my ($DOMAIN) = $ref->{'domain'};
	## my ($DOMAIN) = &DOMAIN::TOOLS::syndication_domain($USERNAME,$PROFILE);
	## my ($PRT) = &ZOOVY::profile_to_prt($USERNAME,$PROFILE);
	
	## default height and width to 75x75
	$ref->{'image_h'} = defined $ref->{'image_h'} ? int($ref->{'image_h'}) : 75;
	$ref->{'image_w'} = defined $ref->{'image_w'} ? int($ref->{'image_w'}) : 75;
	
	## re-check required keys in $ref
	$ref->{'title'} ||= 'title';
	$ref->{'link'} ||= "http://www.$DOMAIN.com";
	$ref->{'subject'} ||= '';
	$ref->{'list'} ||= '';
	
	$ref->{'title'} = sprintf("%s",$ref->{'title'});
	$ref->{'link'} = sprintf("%s",$ref->{'link'});

	my $rss = new XML::RSS (version => 2.0);
	$rss->add_module(prefix=>"ecommerce", uri=>"http://shopping.discovery.com/erss/");
	$rss->add_module(prefix=>"zoovy", uri=>"http://www.zoovy.com/rss/");
	$rss->add_module(prefix=>"media", uri=>"http://search.yahoo.com/mrss/");
	$rss->channel(
		title=>sprintf("%s",$ref->{'title'}),
		link=>sprintf("%s",$ref->{'link'}),
		dc=> {
			date => strftime("%Y-%m-%dT%H:%M:%S-08:00",localtime($NOWTS)),
			subject=>$ref->{'subject'},
			copyright => '2007',
			language => 'en-us',
			},
		syn => {
			updatePeriod			=> "hourly",
			updateFrequency		=> $SEC_REMAIN,
			updateBase				=> strftime("%Y-%m-%dT%H:%M:%S-08:00",localtime($NOWTS)),
			},
		zoovy=> {
			user=>$USERNAME,
			## profile=>$PROFILE,
			prt=>int($ref->{'prt'}),
			list=>sprintf("%s",$ref->{'list'}),
			created=>$CREATEDGMT,
			period=>$period,
			maxproducts=>$max_products,
			expires=>strftime("%Y-%m-%dT%H:%M:%S",localtime($NOWTS + $SEC_REMAIN)),
			},
		);

	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	my $IMAGES_VERSION = int($gref->{'%tuning'}->{'images_v'});	

	
	my ($SITE) = SITE->new( $USERNAME, 'DOMAIN'=>$DOMAIN );
	my ($prodsref) = &PRODUCT::group_into_hashref($USERNAME,$PIDS);
	foreach my $pid (@$PIDS) {
		my $P = $prodsref->{$pid};

		## this line is intentionally commented out and should *ONLY* be used for testing.
		# $pref->{'zoovy:orig_price'} = $pref->{'zoovy:base_price'}; 


		my $rsstitle = $P->fetch('zoovy:prod_rss_title');
		if (not defined $rsstitle) { $rsstitle = $P->fetch('zoovy:prod_name'); }
		if (not defined $rsstitle) { $rsstitle = ''; }
		next if (not defined $rsstitle);


		my $image = $P->fetch('zoovy:prod_image0');
		if (not defined $image) { $image = $P->fetch('zoovy:prod_thumb'); }
		if (not defined $image) { $image = $P->fetch('zoovy:prod_image1'); }

		# my $thumb = &IMGLIB::Lite::url_to_image($USERNAME, $image,75,75,'TTTTTT',0,0,0,$IMAGES_VERSION);
		# my $imageurl =  &IMGLIB::Lite::url_to_image($USERNAME, $P->fetch('zoovy:prod_image1'),$ref->{'image_w'},$ref->{'image_h'},'TTTTTT',0,0,0,$IMAGES_VERSION);
		my $thumb =  sprintf("http://www.$DOMAIN%s",&ZOOVY::image_path($USERNAME, $image,W=>75,H=>75,B=>'TTTTTT',V=>$IMAGES_VERSION));
		my $imageurl =  sprintf("http://www.$DOMAIN%s",&ZOOVY::image_path($USERNAME, $P->fetch('zoovy:prod_image1'),W=>$ref->{'image_w'},H=>$ref->{'image_h'},B=>'TTTTTT',V=>$IMAGES_VERSION));

		my $link = "http://www.$DOMAIN/product/$pid?meta=RSS"; 
		if ($CAMPAIGN eq '') { 
			## CAMPAIGN is not set -- 
			##	q: why would campaign not be set? (a: user site feeds for categories ex: alternativedvd recent prods.)
			## q: wtf is a link_override? 
			if ($ref->{'link_override'}) { $link = $ref->{'link'}; }
			}
		else {
			## CAMPAIGN is set.
			$link = "http://www.$DOMAIN/product/$pid?meta=RSS";
		#	$link = "http://www.$DOMAIN/product/$pid?meta=RSS&cpc=$CAMPAIGN&cpg=$CPGID&cpn=0";
		#	if ($SCHEDULE ne '') {
		#		## ALTER PRICING
		#		# print "USER: $USERNAME SCHEDULE: $SCHEDULE\n";
		#		my $schresults = $P->tweak_product($SCHEDULE);

		#		## rss data format is: 
		#		##		1:pid:price:expires:campaignid:schedule
		#		my ($rssdata) = sprintf("1:%s:%0.2f:%d:%s:%s",$pid,$schresults->{'zoovy:base_price'},$NOWTS+$SEC_REMAIN,$CAMPAIGN,$SCHEDULE);
		#		my ($rsssig) = &ZTOOLKIT::SECUREKEY::gen_signature($SECUREKEY,$rssdata);
		#		$link .= "&_rssd=$rssdata&_rsig=$rsssig";
		#		}
			}

		my $description = $P->fetch('zoovy:prod_desc');


		# media:thumbnail should be: <media:thumnail url="http://shopping.discovery.com/images/products/small/54369.gif" width="100" height="100" />
		# but originally we output this wrong.. 
		my $media = { thumbnail=>{url=>$thumb,width=>$ref->{'image_w'},height=>$ref->{'image_h'}} };
		if ($TRANSLATION eq 'LEGACYV1') {
			# but originally we output media:thumbnail wrong..  and it was media:thumbnail>http:// 
			# and didn't use attributes like yahoo wanted us to in their rdf schema.
			$description = &ZTOOLKIT::htmlstrip($description);
			$media ={ thumbnail=>$thumb };			
			}
		elsif ($TRANSLATION eq 'RAW') {
			## do nothing.
			}
		elsif ($TRANSLATION eq 'HTMLSTRIP') {
			$description = &ZTOOLKIT::htmlstrip($description);
			}
		elsif ($TRANSLATION eq 'WIKISTRIP') {
			$description = &ZTOOLKIT::wikistrip($description);
			}
		elsif (($TRANSLATION eq 'WIKI2HTML') || ($TRANSLATION eq 'WIKI2HTMLIMG')) {

#			$rss->image(
#				title  => sprintf("%s \$%.2f",$P->fetch('zoovy:prod_rss_title'),$P->fetch('zoovy:base_price')),
#				url    => $imageurl,
#				width  =>$ref->{'image_w'},
#				height => $ref->{'image_h'},
#				link   => $link,
#				);

			require Text::WikiCreole;
			$description = &Text::WikiCreole::creole_parse($description);
			if ($TRANSLATION eq 'WIKI2HTMLIMG') {
				my $buyme = $P->button_buyme($SITE,link=>1);
				$description = qq~<table>
<tr>
	<td valign=top><a href="$link"><img border="0" width="$ref->{'image_w'}" height="$ref->{'image_h'}" src="$imageurl"></a></td>
	<td valign=top>$description<br>$buyme</td>
</tr>
</table>
~;

				}
			}
		else {
			$description = '';
			}
		
		$description = sprintf("%s",$description);
		
		$rss->add_item(
			title       => sprintf("%s \$%.2f",$P->fetch('zoovy:prod_rss_title'),$P->fetch('zoovy:base_price')),
			link        => $link,
## THESE FIELDS DON'T SEEM TO DISPLAY:
#			price		  => sprintf("%.2f",$P->fetch('zoovy:base_price')),
#			normalprice => sprintf("%.2f",$P->fetch('zoovy:orig_price')),
#			msrp 		  => sprintf("%.2f",$P->fetch('zoovy:prod_msrp')),
			keywords    => sprintf("%.2f",$P->fetch('zoovy:keywords')),
			description => sprintf("%s",$description),
			content=>{
				encoded=>"$description",
				},
			media=>$media,
			#	thumbnail=>{url=>$thumb,width=>$ref->{'image_w'},height=>$ref->{'image_h'}}
			#	},
			ecommerce=>{
				SKU=>$pid,
				title=>$rsstitle,
				listPrice=>sprintf("%.2f",$P->fetch('zoovy:base_price')),
				origPrice=>sprintf("%.2f",$P->fetch('zoovy:base_price')),
				msrpPrice=>sprintf("%.2f",$P->fetch('zoovy:prod_msrp')),
				imageurl =>$imageurl,
				prodReleaseDate=>sprintf("%s",$P->fetch('zoovy:prod_release_date')),
				},
			);

		} ## END foreach my $pid (@PIDS)


	print STDERR Dumper($rss);

	return $rss->as_string();
	}


1;
