package TOXML::UTIL;

use strict;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;
require TOXML;

@TOXML::WRAPPER_THEME_ATTRIBS = (
	'name','pretty','content_background_color','content_font_face','content_font_size',
	'content_text_color','table_heading_background_color','table_heading_font_face',
	'table_heading_font_size','table_heading_text_color',
	'table_listing_background_color','table_listing_background_color_alternate','table_listing_font_face',
	'table_listing_font_size','table_listing_text_color','link_active_text_color','link_text_color',
	'link_visited_text_color','alert_color','disclaimer_background_color','disclaimer_font_face',
	'disclaimer_font_size','disclaimer_text_color'
	);

#%TOXML::UTIL::minilogos = (
#	'overstock'=>'//static.zoovy.com/img/proshop/W88-H31-Bffffff/zoovy/logos/overstock',	
#	'ebay' => '//static.zoovy.com/img/proshop/W88-H31-Bffffff/zoovy/logos/ebay',
#	'ebaypower' => '//static.zoovy.com/img/proshop/W88-H31-Bffffff/zoovy/logos/ebay',
#	'ebaymotors' => '//static.zoovy.com/img/proshop/W88-H31-Bffffff/zoovy/logos/ebay_motors',
#	'ebaystores' => '//static.zoovy.com/img/proshop/W88-H31-Bffffff/zoovy/logos/ebay_stores',
#	);

## LAYOUT
%TOXML::LAYOUT_PROPERTIES = (
	1<<0 => 'Dynamic Images / Slideshow',
	1<<1 => 'Image Categories / Image Cart',
	);

## WIZARDS
%TOXML::WIZARD_PROPERTIES = (
   1<<0 => 'Standard Fields (payment, shipping, returns, about, contact, checkout)',
	1<<1 => 'Has Header (tabs w/navigation)',
   1<<2 => 'Detailed Description',
   1<<3 => 'Contains Flash',
	);

## WRAPPER
%TOXML::BW_COLORS = (
	1<<0 => 'Black Backgrounds',
	1<<1 => 'Color Backgrounds',
	1<<2 => 'Light Backgrounds',
	1<<3 => 'Grey/Black',
	1<<4 => 'Blue',
	1<<5 => 'Red',
	1<<6 => 'Green',
	1<<7 => 'Other',
	1<<8 => '',
	);

%TOXML::BW_CATEGORIES = (
	1<<0 => 'Staff Favorites',
	1<<1 => 'Seasonal / Xmas',
	1<<2 => 'Seasonal / Valentines',
	1<<3 => 'Seasonal / Other',
	1<<4 => 'Silly Themes',
	1<<5 => 'Locations',
	1<<6 => '',
	1<<7 => 'Industry / Auto',
	1<<8 => 'Industry / Electronics',
	1<<9 => 'Industry / Sporting Goods',
	1<<10 => 'Industry / For Kids',
	1<<11 => '',
	1<<12 => '',
	1<<13 => 'Series 2001',
	1<<14 => 'Series 2002',
	1<<15 => 'Series 2003',
	1<<16 => 'Series 2006',
	1<<17 => 'Series 2007',
	);

%TOXML::BW_PROPERTIES = (
	1<<0 => 'Minicart',
	1<<1 => 'Sidebar',
	1<<2 => 'Subcats',
	1<<3 => 'Search',
	1<<4 => 'Newsletter',
	1<<5 => 'Login',
	1<<6 => 'Image Navcats',
	1<<7 => 'Flex Header',
	1<<8 => 'Web 2.0',
	1<<9 => '',
	1<<10 => '',
	1<<11 => '',
	1<<12 => 'Has Popup',
	1<<13 => 'Has Wizard',
	);



# NOTE: Make sure to add any new flow types into default_flow below also
$TOXML::UTIL::LAYOUT_STYLES = {
	'H' => [ 'Homepage',       'The homepage is the first page to appear on your site.' ],
	'A' => [ 'About Us',       'The purpose of the about us page is to inform customers about how to reach you, as well as to help your company identity.' ],
	'U' => [ 'Contact Us' ,    'The purpose of the Contact Us page is to proved your customers with a way to get in contatc with you.' ],
	'S' => [ 'Search Page' ,   'The purpose of the about us page is to inform customers about how to reach you, as well as to help your company identity.' ],
	'E' => [ 'Results Page',   'The results page is displayed after a search has been performed.'],
	'Y' => [ 'Privacy Policy', 'The purpose of the privacy page is to disclose how you will use the customer information you collect.' ],
	'R' => [ 'Return Page',    'The purpose of the about us page is to inform you customers about your return policy.' ],
	'P' => [ 'Product Page',   'The purpose of the page is to feature a product.' ],
	'C' => [ 'Category Page',  'The purpose of a category page is to provide a hierarchy that makes it easier for customers to find products.' ],
	'X' => [ 'Custom Page',    'A custom page, do with it as you will.' ],
	'D' => [ 'Dynamic Page',   'A dynamic page, provides different data depending on how it is referenced.' ],
	'G' => [ 'Gallery Page',   'A listing of marketplaces and the products listed on them.' ],
	'T' => [ 'Shopping Cart',  'The cart page is displayed after a customer clicks the buy button.' ],
	'L' => [ 'Login',          'When login is required to get access to a feature, this page is displayed.' ],
	'Q' => [ 'Adult Warning',  'Adult Warning (requires ADULT be enabled on the account' ],
	'N' => [ 'Shipping Quote', 'Calculates shipping for auctions' ],
	'B' => [ 'Popup',				'Popup'],
	'I' => [ 'Email/Newsletter', 'An eMail Newsletter you can send to customers'],
	'W' => [ 'Rewards Page', 'Rewards Page Layout' ],
};


##
## FeatureBW
##		1 = Multi Image (3+)
##		
##
##
##
##


sub copy {
	
	## on a wrapper
	##		copy the images to the custom files directory
	##		rename the images 

	}


##
## for a given doc + user
##		selects this docid as it's most recently "remembered" (e.g. selected)
##		adds the entry to TOXML_RANKS (or updates it to selected)
##		updates the RANK for the DOCID in the TOXML table
##
##	STATE =  0 - only remember, do not select.
##				1 - (default) actually remembers this one as selected
##		note: the STATE setting currently does nothing, but i need to make it do something -bh	
##
sub remember {
	my ($USERNAME,$FORMAT,$DOCID,$STATE) = @_;

	if (not defined $STATE) { $STATE = 1; }

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtFORMAT = $dbh->quote($FORMAT);
	my $qtDOCID = $dbh->quote($DOCID);
	my $qtUSERNAME = $dbh->quote($USERNAME);

	my $pstmt = "select count(*) from TOXML_RANKS where MID=$MID and FORMAT=$qtFORMAT and DOCID=$qtDOCID";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($count) = $sth->fetchrow();
	$sth->finish();

	if ($count==0) {
		$pstmt = "insert into TOXML_RANKS (CREATED_GMT,MID,MERCHANT,DOCID,FORMAT) values (".time().",$MID,$qtUSERNAME,$qtDOCID,$qtFORMAT)";
#		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		}

	$pstmt = "update TOXML T, TOXML_RANKS TR set T.RANK_SELECTED=T.RANK_SELECTED-1 where TR.SELECTED=1 and TR.DOCID=T.DOCID and TR.FORMAT=T.FORMAT and TR.MID=$MID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	$pstmt = "update TOXML_RANKS set SELECTED=0 where FORMAT=$qtFORMAT and MID=$MID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	$pstmt = "update TOXML_RANKS set SELECTED=1 where FORMAT=$qtFORMAT and DOCID=$qtDOCID and MID=$MID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	$pstmt = "update TOXML set RANK_SELECTED=RANK_SELECTED+1,RANK_REMEMBER=RANK_REMEMBER+1 where FORMAT=$qtFORMAT and DOCID=$qtDOCID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	&DBINFO::db_user_close();	
	}

##
##
##
sub forget {
	my ($USERNAME,$FORMAT,$DOCID) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $qtDOCID = $dbh->quote($DOCID);
	my $qtFORMAT = $dbh->quote($FORMAT);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "delete from TOXML_RANKS where MID=$MID and FORMAT=$qtFORMAT and DOCID=$qtDOCID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	$pstmt = "update TOXML set RANK_REMEMBER=RANK_REMEMBER-1 where FORMAT='WRAPPER' and MID in (0,$MID) and DOCID=$qtDOCID";
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();

	}





##
## sub updateDB
##
sub updateFILE {
	my ($toxml) = @_;

	my $BINFILE = sprintf("/httpd/static/TOXML_%s.bin",$toxml->format());
	my $ref = {};
	if (-f $BINFILE) {
		$ref = Storable::retrieve("$BINFILE");
		}

	my $SUBTYPE = '';
	my ($el) = $toxml->findElements('CONFIG');
	if (defined $el) { $SUBTYPE = $el->{'SUBTYPE'}; }
	if (not defined $SUBTYPE) { $SUBTYPE = '_'; }
	my $TITLE = (defined $el->{'TITLE'})?$el->{'TITLE'}:'';
		my $cat = int($el->{'CATEGORIES'});
		my $col = int($el->{'COLORS'});

	$ref->{$toxml->{'_ID'}} = {
		'MID'=>0,
		'FORMAT'=>$toxml->{'_FORMAT'},
		'SUBTYPE'=>$SUBTYPE,
		'TITLE'=>$TITLE,
		'PROPERTIES'=> int($el->{'PROPERTIES'}),
		'WRAPPER_CATEGORIES'=>$cat,
		'WRAPPER_COLORS'=>$col,
		};

	Storable::store($ref,$BINFILE);
	}





##
## valid OPTIONS: 
##		SUBTYPE
##		[bitwise] DETAIL=>	0 (default) not supplied FORMAT, MID, SUBTYPE, DIGEST, UPDATED_GMT, TEMPLATE
##					1 (returns config element)
##					2 (filter results to only returns non-MID 0 files)
##		SORT => 1 (sorts by placing favorites first)
##		DEREPCATED=>1 (include deprecated documents)
##
##	returns:
##		an array of hashes, each hash has:
##			DOCID,SUBTYPE,FORMAT,DIGEST,UPDATED_GMT,TITLE,MID
##
sub listDocs {
	my ($USERNAME,$FORMAT,%options) = @_;

	if ($FORMAT eq 'EMAIL') { $FORMAT = 'ZEMAIL'; }
	if (not defined $options{'DETAIL'}) { $options{'DETAIL'} = 0; }

	my @AR = ();
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %RANKS = ();


	## Load system templates
	if (-f "/httpd/static/TOXML_$FORMAT.bin") {
		require Storable;
		my $REFS = Storable::retrieve("/httpd/static/TOXML_$FORMAT.bin");
		foreach my $ID (keys %{$REFS}) {
			my $ref = $REFS->{$ID};
			next if ((defined $options{'DEPRECATED'}) && ($ref->{'CREATED_GMT'} == 0));
			next if ((defined $options{'SUBTYPE'}) && ($ref->{'SUBTYPE'} ne $options{'SUBTYPE'}));
			if ($ref->{'CREATED_GMT'}==0) { $ref->{'CREATED_GMT'} = 1293234232; }
			$ref->{'DOCID'} = "$ID";
			$ref->{'UPDATED_GMT'} = 0;
			push @AR, $ref;
			}

		}


	if ($USERNAME ne '') {
		my $userpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML';
		opendir TDIR, "$userpath";
		while (my $file = readdir(TDIR)) {
			my %INFO = ();
			next if (substr($file,0,1) eq '.');
			next unless ($file =~ m/^([A-Z]+)\+(.*)\.bin$/i);
			$INFO{'FORMAT'} = $1;
			$INFO{'DOCID'} = '~'.$2;
			next if ($INFO{'FORMAT'} eq '');
			next if ($INFO{'FORMAT'} eq 'DEFINITION');
			next if ($INFO{'DOCID'} eq '');
			next if (($FORMAT ne '') && ($FORMAT ne $INFO{'FORMAT'}));
			$INFO{'MID'} = $MID;
			$INFO{'UPDATED_GMT'} = time();
			$INFO{'ID'} = -1;
			$INFO{'STARS'} = 10.5;
			$RANKS{ $INFO{'DOCID'} } = $INFO{'STARS'};

			next if ((defined $options{'SUBTYPE'}) && ($INFO{'SUBTYPE'} ne '') && ($options{'SUBTYPE'} ne $INFO{'SUBTYPE'}));

			push @AR, \%INFO;
			}
		closedir TDIR;
		}


	if ($options{'SELECTED'} ne '') {	
		## if one is selected, make sure it appears in the list.
		my $selected_found = 0;
		foreach my $inforef (@AR) {
			if ($inforef->{'DOCID'} eq $options{'SELECTED'}) { $selected_found++; }
			}
		if (not $selected_found) {
			$RANKS{$options{'SELECTED'}} = 11;
			unshift @AR, { DOCID=>$options{'SELECTED'}, FORMAT=>$FORMAT, TITLE=>$options{'SELECTED'} };
			}
		}


	if (($options{'DETAIL'}&1)==1) {
		my $x = scalar(@AR);
		for (my $i =0;$i<$x;$i++) {
			next if ($AR[$i]->{'DOCID'} eq '');						## corrupt
			next if ($AR[$i]->{'FORMAT'} eq 'DEFINITION');		## ignore

			my ($t) = TOXML->new($AR[$i]->{'FORMAT'},$AR[$i]->{'DOCID'},USERNAME=>$USERNAME,MID=>$MID);
			next if (not defined $t);
			my ($CONFIGEL) = $t->findElements('CONFIG');
			if (defined $CONFIGEL) {
				delete $AR[$i]->{'TITLE'};	# delete TITLE so we can reset it in the next step.
				foreach my $k (keys %{$CONFIGEL}) {
					next if (defined $AR[$i]->{$k});		# never override properties which have already been set. (ex: ID)
					$AR[$i]->{$k} = $CONFIGEL->{$k};
					}
				}
			}
		}


	## sort the items based on popularity
	if ($options{'SORT'}==1) {
		## step1: convert our current @AR into %H (key = DOCID, value = ref)
		my %H = ();
		foreach my $ref (@AR) { 
			$H{$ref->{'DOCID'}} = $ref; 
			}
		@AR = (); # everything is stored in %H so this is safe.
		foreach my $docid (reverse sort keys %H) { push @AR, $H{$docid}; }
		undef %H;
		}


	return(\@AR);
	}


##
## Format: P (product)
##
sub favoriteDocs {
	my ($USERNAME, $FORMAT, $SUBTYPE) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select DOCID from TOXML_RANKS where MID=".$MID." and FORMAT=".$dbh->quote($FORMAT);
	# $pstmt .= " and SUBTYPE=$SUBTYPE";
	$pstmt .= " order by DOCID";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my @docs = ();
	while ( my ($docid) = $sth->fetchrow() ) {
		push @docs, $docid;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(@docs);
	}

1;
