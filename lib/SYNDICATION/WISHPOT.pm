#!/usr/bin/perl

package SYNDICATION::WISHPOT;

use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZSHIP;
use ZTOOLKIT;
use SYNDICATION;
use SITE;
use ZTOOLKIT::SECUREKEY;

sub new {
	my ($class, $so) = @_;
	my ($self) = {};

	$self->{'_SO'} = $so;
   tie my %s, 'SYNDICATION', THIS=>$so;

	# my $nsref = &ZOOVY::fetchmerchantns_ref($so->username(),$so->profile());
	# my $vmid = $nsref->{'wishpot:merchantid'}; # $s{'.merchantid'};
	my $vmid = $so->get('.merchantid');
	my $USERNAME = $so->username();
	my $domain = lc($so->domain());

	$self->{'_DOMAIN'} = $domain;
	print "VMID: $vmid / DOMAIN: $domain\n";
	$domain =~ s/[^a-z0-9]/_/g;
	
	## VERUTA USES A HARDCODED MERCHANT ID/DOMAIN
	# Server: feeds.wishpot.com User: Zoovy Password: +p!f7w@2p
	$so->set('.url',"ftp://Zoovy:%2Bp%21f7w%402p\@feeds.wishpot.com/zoovy-$USERNAME-$domain-$vmid.xml");
	bless $self, 'SYNDICATION::WISHPOT';  

	return($self);
	}

sub header_products {
	my ($self) = @_;

	my $USERNAME = $self->so()->username();
#	my ($key) = &ZTOOLKIT::SECUREKEY::gen_key($self->so()->username(),'WP');
#	$self->so()->set('.key',$key);

	my $vmid = $self->so()->get('.merchantid');

	my $CREATED = &ZTOOLKIT::pretty_date(time(),2);

	my $zoovyxml = qq~<Zoovy>
<MerchantID>$vmid</MerchantID>
<Username>$USERNAME</Username>
<Domain>$self->{'_DOMAIN'}</Domain>
<Created>$CREATED</Created>
<SecureKey>$key</SecureKey>
</Zoovy>~;

	my ($nc) = NAVCAT->new($USERNAME,PRT=>$self->so->prt());
	foreach my $safe ($nc->paths()) {
		my ($pretty,$children,$products,$sortby,$metaref) = $nc->get($safe);
		## ! = don't send hidden categories
		if (substr($pretty,0,1) eq '!') { $pretty = substr($pretty,1); }
		$pretty = &ZOOVY::incode($pretty);
		my ($active) = int($metaref->{'WSH'});

		## WISHPOT: don't send -1 or -2 categories
		my $suppress = ($active>0)?0:1;

		#if ($active>=0) {
		## somehow wishpot got our wires crossed, and active really means "suppress"
		## 1= do not list
		## 0= clear to list
		## NOTE: I've added a "suppress" tag, that wishpot can start using that means the same thing, but makes
		##			a HECK of a lot more sense.
		$zoovyxml .= "<Category active=\"$suppress\" suppress=\"$suppress\" id=\"$safe\" pretty=\"$pretty\">$products</Category>\n";
		#	}
		}

	return(q~<Products>~.$zoovyxml);
	}

sub so { return($_[0]->{'_SO'}); }


## validate
##	note: added check for wishpot:ts<0 2011-03-01 
##	addl note: wasn't pushed until 2011-08-02
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	my $ERROR = '';

	## check wishpot:ts
	if ($ERROR) {}
	elsif ($P->fetch('wishpot:ts')<0) {
		$ERROR = "{wishpot:ts}wishpot:ts is not enabled .. cannot syndicate";
		}

	if ($ERROR ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { $ERROR = ''; }
		}
	return($ERROR);
	}

##
##
##  
sub product {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $csv = $self->{'_csv'};

	my $USERNAME = $self->so->username();

	

	my $out = '';
#<Item>
#<ItemID>02-001P</ItemID>
#<Title>X-11 BLACK</Title>
#.
#<Description>
#SHOEI X-Eleven Motorcycle Helmet &nbsp;  The X-ELEVEN has been the helmet of choice for professional riders since its  introduction. Built to race specifications, the X-Eleven was designed and  developed in collaboration with professional riders, like Jake Zemke, Eric  Bostrom, and Chris Vermeulen to name a few.  Numerous hours in our wind tunnel and on racetracks around the world has  produced an aerodynamically superior helmet with minimal lift and drag, plus  incomparable fit and ventilation.  The worlds most demanding riders demand nothing but the best. The X-ELEVEN  only from Shoei.  Quick Release Base Plate System  Dual Liner Ventilation System  3D Comfort Liner System  Upper Air Intake  Lower Air Intake  Dual Air Charge System  Face Shield Defogging Vent  Chin Curtain  Rear Air Exhaust  Neck Outlet Vent  Exhaust Breath Chamber  Breath Guard  Aero Edge Spoiler With Exhaust Vent  Preset Shield Opening Lever With Locking Mechanism  CX-1V Shield (Clear shield included)  AIM+Shell Construction  Snell M2005  5 Year Warranty From Purchase Date. 7 Year Warranty From Helmet  Manufacture Date X-Eleven Specifications
#</Description>
#<LinkUrl>http://www.extrememoto.com/p/02-001/</LinkUrl>
#.
#<ImageUrl>
#http://www.extrememoto.com/images/hh_l/02-001_l.jpg
#</ImageUrl>
#<CategoryIDList>Full-Face-Helmet</CategoryIDList>
#<MinPrice>529.19</MinPrice>
#<MaxPrice>587.99</MaxPrice>
#<SpecialOffer/>
#</Item>
	

	require XML::Writer;
	require IO::String;
	
	my $io = IO::String->new;

	my $writer = new XML::Writer(OUTPUT => $io);
   $writer->startTag("Product","sku"=>"$SKU");

	foreach my $k (
		'zoovy:prod_name',
		'zoovy:prod_desc',
		'zoovy:prod_detail',
		'zoovy:prod_image1',
		'zoovy:base_price',
		'zoovy:prod_msrp',
		) {
		my $tag = $k;
		$tag =~ s/\:/\-/g;
		$writer->dataElement($tag,&ZTOOLKIT::stripUnicode($P->fetch($k)));
		}
	

	my $domain = $self->{'_DOMAIN'};

	# 100x100,  177x160,  500x500
	my $imgurl = &ZOOVY::mediahost_imageurl($USERNAME,$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
	$writer->dataElement("ImageUrl",$imgurl);
	$imgurl = &ZOOVY::mediahost_imageurl($USERNAME,$P->fetch('zoovy:prod_image1'),100,100,'FFFFFF',0,'jpg'); 
	$writer->dataElement("ImageUrl-100x100",$imgurl);
	$imgurl = &ZOOVY::mediahost_imageurl($USERNAME,$P->fetch('zoovy:prod_image1'),177,160,'FFFFFF',0,'jpg'); 
	$writer->dataElement("ImageUrl-177x160",$imgurl);

	$writer->dataElement("LinkUrl",$OVERRIDES->{'zoovy:link2'});

	$writer->dataElement("Inventory",$OVERRIDES->{'zoovy:qty_instock'});

	my $tmpcat = $P->fetch('zoovy:prod_category');
	$writer->dataElement("Category",$tmpcat);

	## other properties
	$writer->dataElement("HasVariations", ($P->has_variations('inv')?'false':'true') );
	$writer->dataElement("RelatedItems",$P->fetch('zoovy:related_products'));
	$writer->dataElement("AccessoryItems",$P->fetch('zoovy:related_products'));

	$writer->endTag("Product");
	$writer->end();

	my $xml = ${$io->string_ref()};
	$io->close();

	return($xml."\n");
	}


##
##
##
sub cleanup {
	my ($self) = @_;
	## make sure we don't store the zoovy credentials in userspace.
	$self->so()->set('.url','');
	return();
	}
  
sub footer_products {
  my ($self) = @_;
  return("</Products>");
  }


1;
