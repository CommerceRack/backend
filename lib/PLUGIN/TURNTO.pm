package PLUGIN::TURNTO;


use Data::Dumper;

##
## TURNTO 
##		built for user orange onions.
##		tech contact: Eric Clay 3147490196 (cell) EST time.
##
## 	turntotest.com dovi@kutoff.com 1234
##		turnto.com dovi@kutoff.com 5216dk
##


use strict;

#use XML::Writer;
#use IO::String;
#use IO::Scalar;
use POSIX qw(strftime);
use Text::CSV_XS;



sub iframe {
	my ($USERNAME) = @_;
	return(q~
<!-- BEGIN TURNTO -->

<div id="TTembed"></div>

<script type="text/javascript">
var turnToConfig = {host: "www.turnto.com", siteKey: "KW7Az41VbW4vw5qsite" };
</script>

 
<script type="text/javascript">
document.write(unescape("%3Cscript src='" + (("https:" == document.location.protocol) ? "https://" : "http://") + turnToConfig.host + "/tra/turntoEmbed.js'  type='text/javascript'%3E%3C/script%3E"));
</script>
<!-- END TURNTO -->
~);
	};


#sub send_order {
#	my ($o) = @_;
#	my ($USERNAME) = $o->username();
#	&PLUGIN::TURNTO::send_orders($USERNAME,[$o]);
#	}
#
#
#sub send_orders {
#	my ($USERNAME,$oarray) = @_;
#
#
#	my ($IS_TEST,$SITE_KEY,$AUTH_KEY) = (undef,undef,undef);
#	if ($USERNAME eq 'orangeonions') {
#		# $AUTH_KEY = 'rT5nvFMgdk4jACpauth'; $SITE_KEY = 'GCQ3KlbJXsomlcpsite';	$IS_TEST++; # TurnToTest
#		$AUTH_KEY = 'vpjubYnshMHsMgqauth'; $SITE_KEY = 'KW7Az41VbW4vw5qsite'; # TurnToLive
#		}
#
#	## per eric non-rfc 4180
#	##	 entity encode all tsv columns
#	##	 strip tabs from data.
#	my $csv = Text::CSV_XS->new({sep_char=>"\t",quote_char=>"",escape_char=>""});          # create a new object	
#	## header row
#	my @headers = ();
#	push @headers, 'ORDERID';
#	push @headers, 'ORDERDATE';
#	push @headers, 'EMAIL';
#	push @headers, 'ITEMTITLE';
#	push @headers, 'ITEMURL';
#	push @headers, 'ITEMLINEID';
#	push @headers, 'ZIP';
#	push @headers, 'FIRSTNAME';
#	push @headers, 'LASTNAME';
#	push @headers, 'SKU';
#	push @headers, 'PRICE';
#	push @headers, 'ITEMIMAGEURL';
#	my $status  = $csv->combine(@headers);
#	my $line    = $csv->string();
#	my $out = $line."\r\n";
#
#	my $OID = undef;
#	my $count = 0;
#	foreach my $OorOID (@{$oarray}) {
#		my $o = undef;
#		if (ref($OorOID) eq 'ORDER') {
#			## we got sent an order object.
#			$o = $OorOID;
#			}
#		elsif (ref($OorOID) eq '') {
#			## load from disk
#			($o) = ORDER->new($USERNAME,$OorOID,create=>0);
#			}
#		elsif (not defined $o) {
#			die("OorOID: $OorOID");
#			}
#
#		my $skip = 0;
#		## turnto doesn't want amazon orders!
#		my $mkt = $o->get_attrib('mkt');
#
#		if ($o->get_attrib('mkt') & (1<<5)) { $skip++; }
#
#		if (not $skip) {
#			$count++;
#			$OID = $o->oid();
#			my ($line) = &PLUGIN::TURNTO::buildTab($csv,$o);
#			$out .= $line;
#			}
#
#		}
#
#	my ($success) = 0;
#	if (($out ne '') && ($count>0)) {
#		use LWP::UserAgent;
#		use HTTP::Request::Common;
#		#my $file = IO::String->new($out);
#		#my ($x) = IO::Scalar->new(\$out);
#
#		my $ua = LWP::UserAgent->new();
#		my $request = HTTP::Request->new();
#		my $response;
#		my $header;
#		
#		my $url = "http://www.turnto.com/feedUpload/postfile";
#		if ($IS_TEST) {
#			$url = "http://www.turntotest.com/feedUpload/postfile";
#			}
#
#		use File::Temp;
#		my $fname = tmpnam();
#		if (scalar(@{$oarray})>1) {
#			$fname = sprintf("/tmp/turnto-batch-%s",strftime("%Y%m%dT%H%M%S%z", localtime(time())));
#			}
#		else {
#			$fname = sprintf("/tmp/turnto_%s",$OID);
#			}
#		open F, ">$fname"; print F $out; close F;
#
#		# The POST method also supports the "multipart/form-data" content used for Form-based File Upload as specified in RFC 1867. 
#		$response = $ua->request(POST $url, 
#			Content_Type => 'form-data', 
#			Content => { siteKey => "$SITE_KEY", feedStyle=>"tab-style.1", authKey => "$AUTH_KEY", file=>[$fname]  }
#			);
#
#		unlink($fname);
##		print $response->as_string;
##		print $response->decoded_content;
#		$success = ($response->is_success)?1:0;
#		}
#	return($success);
#	}
#
#
###
### 
###
#sub buildTab {
#	my ($csv, $o) = @_;
#
#	my $out = '';
#
#	my $s = $o->stuff();
#	foreach my $stid (sort $s->stids()) {
#		my ($item) = $s->item($stid);
#		my @columns = ();		
#	
#		my $SKU = $item->{'sku'};
#		if ((not defined $SKU) || ($SKU eq '')) { $SKU = $item->{'product'}; }
#
##	push @headers, 'ORDERID';
#		push @columns, $o->oid();
##	push @headers, 'ORDERDATE';
#		push @columns, strftime("%Y-%m-%dT%H:%M:%S%z", localtime($o->get_attrib('created')));
##	push @headers, 'EMAIL';
#		push @columns, $o->get_attrib('bill_email');
##	push @headers, 'ITEMTITLE';
#		push @columns, $item->{'prod_name'};
##	push @headers, 'ITEMURL';
#		push @columns, sprintf("http://%s/product/%s?meta=TURNTO",$o->get_attrib('sdomain'),$SKU);
##	push @headers, 'ITEMLINEID';
#		push @columns, $stid;
##	push @headers, 'ZIP';
#		push @columns, $o->get_attrib('bill_zip');
##	push @headers, 'FIRSTNAME';
#		push @columns, $o->get_attrib('bill_firstname');
##	push @headers, 'LASTNAME';
#		push @columns, $o->get_attrib('bill_lastname');
##	push @headers, 'SKU';
#		push @columns, $SKU;
##	push @headers, 'PRICE';
#		push @columns, $item->{'price'};
##	push @headers, 'ITEMIMAGEURL';
#		push @columns, &GTOOLS::imageurl($o->username(),$item->{'%attribs'}->{'zoovy:prod_image1'},75,75,undef,0,'jpg');
#			
#		my $i = scalar(@columns);
#		while (--$i>0) {
#			$columns[$i] =~ s/[\t]//gs;
#			$columns[$i] = &ZOOVY::incode($columns[$i]);
#			}
#		
#		my $status  = $csv->combine(@columns);	
#		my $line    = $csv->string ();	
#		$out .= $line."\r\n";
#		}
#	
#	## 
#	
#	return($out);
#	}
#
#
#
#
#
#
#
#
#
#
1;