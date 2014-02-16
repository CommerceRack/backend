#!/usr/bin/perl

package SYNDICATION::LINKSHARE;


##
## this creatse a csv file for 
## http://static.zoovy.com/merchant/tting/TICKET_0-MerchandiserGuidelinesAdvertisersv_4_6.pdf
##
##	135029	


use POSIX qw(strftime);
use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZTOOLKIT;
use Data::Dumper;


##
## custom upload method because linkshare needs two files.
##
sub upload {
	my ($self,$FILENAME, $tlm) = @_;

	my ($so) = $self->so();
   tie my %s, 'SYNDICATION', THIS=>$so;

	my ($DATE) = POSIX::strftime("%Y%m%d",localtime());
	
	# 1234_nmerchandis20090310.txt
	my $remote_merchandise_file = sprintf("%d_nmerchandis%d.txt",$so->get('.linkshare_mid'),$DATE);
	# 1234_nattributes20090310.txt
	my $remote_attributes_file = sprintf("%d_nattributes%d.txt",$so->get('.linkshare_mid'),$DATE);

	
	my $USERNAME = $so->username();
	my $LOCAL_ATTRIBUTES_FILE = "/tmp/$USERNAME-LNK-attribs.txt";

	if (1) {
		open F, ">$LOCAL_ATTRIBUTES_FILE";
		## ATTRIBUTE HEADER
		my $line = "HDR|$s{'.linkshare_mid'}|$s{'.linkshare_company'}|$self->{'.datetime'}\r\n";
		print F $line;
		## ATTRIBUTE BODY	
		my $trl_count = 0;
		foreach $line (@{$self->{'@attrib-lines'}}) {
			next if ($line eq '');
			print F "$line\r\n";
			$trl_count++;
			}
		## ATTRIBUTE FOOTER
		$line = sprintf("TRL|%d\r\n",$trl_count);
		print F $line;
		close F;
		}

	if ($tlm->can_proceed()) {
		## transfer_ftp should set SUCCESS when it finishes with no errors
		$so->transfer_ftp("",[
			{ in=>$FILENAME, out=>$remote_merchandise_file },
			{ in=>$LOCAL_ATTRIBUTES_FILE, out=>$remote_attributes_file },
			],$tlm);
		}
	
	if ($tlm->has_win()) {
		## eventually we might save the attributes file here. 
		unlink("$LOCAL_ATTRIBUTES_FILE");
		}
	else {
		$tlm->pooshmsg("WARN|+non-win from transfer_ftp, preserving file $LOCAL_ATTRIBUTES_FILE");
		}

	return($tlm);
	}



##
## creates a new SYNDICATION::THEFIND object 
##		$so is the SYNDICATION object which created it (the parent)
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	
	if ($s{'.ftp_server'} =~ /^ftp\:\/\//i) { $s{'.ftp_server'} = substr($s{'.ftp_server'},6); }
	#if ($s{'.ftp_server'} !~ /yahoo\.com$/) {
	#	$ERROR = 'FTP Server must end in .yahoo.com'; 
	#	}

	## how do we send the data to the find?  .. the actual data transfer happens in $so -- but when we create
	##	our object we need to tell $so how/where it's going to send the file to thefind. 
	$self->{'%id'} = {};
	my ($USERNAME) = $so->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select SKU,ID from SYNDICATION_LINKSHARE_ID where MID=$MID /* $USERNAME */";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($SKU,$ID) = $sth->fetchrow() ) {
		$self->{'%id'}->{$SKU} = $ID;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	# 2000.02.14/20:30:40
	# sprintf("ftp://%s:%s\@%s/%s/data.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'}));
	## don't worry about this line -- *YET* .. it creates an object but you don't need to understand it.
	bless $self, 'SYNDICATION::LINKSHARE';  
	untie %s;

	

	$self->{'.datetime'} = POSIX::strftime("%Y.%m.%d/%H:%M:%S",localtime());
	$self->{'.linecounter'}=0;
	$self->{'@attrib-lines'} = [];

	return($self);
	}


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;

	if (&SYNDICATION::declaw($P->fetch('zoovy:prod_desc')) eq '') { 
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_desc|+product description is not specified";
		}
	elsif (SYNDICATION::declaw($P->fetch('zoovy:prod_name')) eq '') {
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_name|+product name is not set";
		}
	
	return($ERROR);
	}


##
## this creates the header row. 
##
sub header_products {
	my ($self) = @_;

	my ($so) = $self->so();
   tie my %s, 'SYNDICATION', THIS=>$so;
	my $dateandtime = 
	
	$self->{'.linecounter'} = 0; ## NOTE: header doesn't count as a line.
	my $line = "HDR|$s{'.linkshare_mid'}|$s{'.linkshare_company'}|$self->{'.datetime'}\r\n";
	return($line);
	}

## 
## a quick and dirty sub to our parent.
##		so we can go $self->so()->____  where ___ is a function in SYNDICATION.pm such as "addLog"
##
sub so { return($_[0]->{'_SO'}); }


##
## this function is called by our parent $self->so() once per product
##	 it's job is to create a line per product, or return blank if no line should be created.
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my @columns = ();

	# 1 Product ID Number Required
	# Unique ID used to identify a product. Must be an integer greater than 2 
	# and must have less than 31 total characters. It should not be padded with 
	# leading zeros (eg, 00001001). All future references to a given product use this ID.
	my $id = $P->fetch('linkshare:id');
	if ((not defined $id) || ($id==0)) {
		## see if we have a linkshare id.
		$id = $self->{'%id'}->{uc($SKU)};
		}
	if ((not defined $id) || ($id==0)) {
		## add a new linkshare id
		my ($USERNAME) = $self->so()->username();
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);

		my $nextid = int($self->so()->get('.lastid'))+1;
		if ($nextid<1000) { $nextid = 1000; }

		my $exists = 1;
		while ( $exists ) {
			$nextid++;
			my $pstmt = "select count(*) from SYNDICATION_LINKSHARE_ID where MID=$MID /* $USERNAME */ and ID=".int($nextid);
			print STDERR $pstmt."\n";
			($exists) = $udbh->selectrow_array($pstmt);
			}

		my ($pstmt) = &DBINFO::insert($udbh,'SYNDICATION_LINKSHARE_ID',
			{
			'MID'=>$self->so()->mid(),
			'SKU'=>$SKU,
			'ID'=>$nextid
			},key=>['MID','SKU'],sql=>1);
		print $pstmt."\n";
		$udbh->do($pstmt);

		$id = $nextid;
		$self->so()->set('.lastid',$id);
		&DBINFO::db_user_close();		
		}
	if ($id==0) {
		warn "ID could not be set or established"; die();
		return(undef);
		}
	push @columns, $id;

	#2 Product Name VarChar2(255) Required Product name.
	push @columns, $P->fetch('zoovy:prod_name');

	#3 Sku Number VarChar2(40) Required SKU Number.
	push @columns, "$SKU";

	#4 Primary Category VarChar2(50) Required
	# Primary product category, as defined by you. Please use top.level category (Apparel) or bottom.level 
	#  category (Jeans) only. Using both may exceed the character limit for the field.
	my @cats = split(/\./,$OVERRIDES->{'navcat:safe'});	
	my $primarycat = '';
	if (scalar(@cats)==0) { $primarycat = 'Other'; } 
	elsif (scalar(@cats)==1) { $primarycat = pop @cats; }
	else {
		## take first and last safename
		$primarycat = sprintf("%s.%s",shift @cats,pop @cats);
		}
	push @columns, $primarycat;

	#5 Secondary Category(ies) VarChar2(2000) Optional Secondary product categories, 
	# delimited with double tildes (~~).
	push @columns, "";	

	# 6 Product URL VarChar2(2000) Required URL of the product page . links will direct to this page.
	push @columns, $OVERRIDES->{'zoovy:link2'};

	# 7 Product Image URL VarChar2(2000) Required URL of product image. This must be an absolute URL.
	if ($P->fetch('zoovy:prod_image1')) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}

	# 8 Buy URL VarChar2(2000) Optional URL of shopping cart with product.
	push @columns, "";	

	# 9 Short Product Description VarChar2(500) Required Short description of product in plain text, not HTML
	push @columns, &SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));

	# 10 Long Product Description
	# VarChar2(2000) Optional Long description of product in plain text, not HTML 
	push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_detail'));

	# 11 Discount Number Optional
	# Relies on discount type (below) to determine how to apply. If Discount Type is amount, then discount is 
	# deducted. If it is a percentage, then percentage is deducted.
	push @columns, "";	

	# 12 Discount Type VarChar2(255) Optional Values: amount or percentage.
	push @columns, "";	

	# 13 Sale Price Number Optional This price reflects any discounts.
	push @columns, $P->fetch('zoovy:base_price');	

	# 14 Retail Price Number Required This price does not reflect any discounts.
	push @columns, $P->fetch('zoovy:base_price');	

	# 15 Begin Date Date(mm/dd/yyyy) Optional Date that the product becomes available.
	push @columns, "";	

	# 16 End Date Date(mm/dd/yyyy) Optional Date that the product ceases to become available.
	push @columns, "";	

	# 17 Brand VarChar2(255) Optional Brand name.
	push @columns, $P->fetch('zoovy:prod_brand');	

	# 18 Shipping Number Optional The cost of the default shipping option available.
	push @columns, $P->fetch('zoovy:ship_cost1');	

	# 19 Is Deleted Flag VarChar2(1) Y/N Required N if product should appear in the interface, otherwise Y. Default is N.
	push @columns, "N";	

	# 20 Keyword(s) VarChar2(500) Optional Keywords for searches, delimited with double tildes (~~).
	push @columns, $P->fetch('zoovy:prod_keywords');

	# 21 Is All Flag VarChar2(1) Y/N Required Y if product is to appear in all offers. Otherwise N. Default is Y.
	push @columns, "Y";	

	# 22 Manufacturer Part # VarChar2(50) Optional Manufacturer.s part number (may sometimes be the same as SKU).
	push @columns, $P->fetch('zoovy:prod_mfgid');	

	# 23 Manufacturer Name VarChar2(250) Optional Manufacturer.s name.
	push @columns, $P->fetch('zoovy:prod_mfg');	

	# 24 Shipping Information VarChar2(50) Optional Text.based shipping information . provides 
	# information on the default shipping option.
	push @columns, "";	

	# 25 Availability VarChar2(50) Optional Denotes whether the product is in stock.
	push @columns, ($OVERRIDES->{'zoovy:qty_instock'})?'In Stock':'Out of Stock';

	# 26 Universal Product Code VarChar2(15) Optional Universal Product Code.
	push @columns, $P->skufetch($SKU,'zoovy:prod_upc');	

	# 27 Class ID Number
	# Required, only if you are submitting an Attribute File
	# Classification ID based on product type (see Appendix B Class Definition Table).
	my $ClassID = 0;
	if (defined $P->fetch('linkshare:classid')) {
		$ClassID = int($P->fetch('linkshare:classid'));
		}
	else {
		$ClassID = $self->so()->get('.linkshare_default_classid');
		}
	push @columns, $ClassID;	## Electronics

	# 28 Is Product Link Flag VarChar2(1) Y/N Required
	# Y if product is to be offered to publisher as Individual Product Link in Create
	# Links section. Otherwise N.
	push @columns, "Y";	

	# 29 Is Storefront Flag VarChar2(1) Y/N Required 
	# Y if product is to be used in creating Storefronts for publishers. Otherwise N.
	push @columns, "Y";	

	# 30 Is Merchandiser Flag VarChar2(1) Y/N Required
	# Y if product is to be offered to publisher in Merchandiser product file FTP. Otherwise N.
	push @columns, "Y";	

	# 31 Currency VarChar2(3) Required The three.character ISO Currency Code. Default is USD.
	push @columns, "USD";	

	# 32 M1 VarChar2(2000) Optional Please leave null unless otherwise instructed.
	push @columns, "";	

	foreach my $c (@columns) {
		$c =~ s/[\n\r\|]+//gs;
		}

	my $line = join("|",@columns);
	$self->{'.linecounter'}++;

	my @attribs = ();
	push @attribs, $P->fetch('db:id');

	if (not defined $ClassID) {
		}
	elsif ($ClassID == 10) {
		## Books
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 20) {
		## Music
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 30) {
		## Movies
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 40) {
		## Computer Hardware
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 50) {
		## Computer Software
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 50) {
		## 
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 60) {
		## Clothing and Accessories
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 70) {
		## Art
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 80) {
		## Toys
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 90) {
		## Pets
		## does not use ClassID
		}
	elsif ($ClassID == 100) {
		## Games
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 110) {
		## Food & Drink
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 120) {
		## Gifts & Flowers
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 130) {
		## Auto
		push @attribs, $ClassID;
		}
	elsif ($ClassID == 140) {
		## Electronics
		# 1 Product ID Number Product ID (must match ID from Primary File)
		# 2 Class ID Number Class ID
		push @attribs, $ClassID;
		# 3 Miscellaneous VarChar2(128) Extraneous Information
		push @attribs, $P->fetch('zoovy:prod_misc');
		# 4 Category VarChar2(128) Product sub.category . type of product (CD/DVD player, PDA, etc.)
		push @attribs, $P->fetch('zoovy:prod_type');
		# 5 Model VarChar2(128) Model
		push @attribs, $P->fetch('zoovy:prod_model');
		# 6 Features/Specs VarChar2(128) Features and Specifications
		push @attribs, $P->fetch('zoovy:prod_features');
		# 7 Color VarChar2(128) Color
		push @attribs, $P->fetch('zoovy:prod_color');
		# 8 Dimensions VarChar2(50) L x W or L x W x H
		push @attribs, sprintf("%d x %d x %d",$P->fetch('zoovy:prod_length'),$P->fetch('zoovy:prod_width'),$P->fetch('zoovy:prod_height'));
		# 9 Power Type VarChar2(128) AC/DC, battery, solar
		push @attribs, $P->fetch('zoovy:prod_power');
		# 10 Warranty VarChar2(128) Length of Warranty
		push @attribs, $P->fetch('zoovy:prod_warranty');
		}
	elsif ($ClassID == 150) {
		## Credit Cards
		## does not use ClassID
		}

	if (scalar(@attribs)>1) {
		push @{$self->{'@attrib-lines'}}, join("|",@attribs);		
		}

	return($line."\n");
	}
  


##
## this generates a footer, it's called by $so after all the products are done.
##  since csv files don't have footers (but XML files do) it can probably output blank.. unless it's xml
## then it should return </endtag> or whatever the ending is. 
sub footer_products {
	my ($self) = @_;

	my $count = int($self->{'.linecounter'});
	return("TRL|$count\r\n");
	}


1;
