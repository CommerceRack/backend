package ZWEBAPI;

use strict;

use Data::Dumper;

use lib '/backend/lib';
require ZOOVY;

##
## parameters:
## username, timestamp (unixtime), url, contents
##
sub log_request {
	my ($USERNAME,$URL,$CONTENTS) = @_;
	my $TIMESTAMP = time();

#	my $FILENAME  = "$USERNAME.$TIMESTAMP.$$.txt";
#	mkdir('/local/webapi');
#	if (defined $CONTENTS && $CONTENTS ne '') {
#		open F, ">/local/webapi/$FILENAME";
#		print F $CONTENTS;
#		close F;
#		} else {
#		$FILENAME = '';
#		}
#	open F, ">>/local/webapi/requests.log";
#	print F "$USERNAME|$TIMESTAMP|$URL|$FILENAME\n";
#	close F;
}

##
## note: this is a cheap XML incode, it only does the upper 128 bytes, which is probably safe.
##
sub xml_incode
{
	my ($str) = @_;

	my $new = '';
	foreach my $c (split(//,$str))
		{
		if (ord($c)>=127)
			{
			# remember to skip these characters
			if ($c eq '>' || $c eq '<' || $c eq '&')
				{
				$new .= $c;
				} else {
				$new .= '&#'.ord($c).';';	
				}
			} else {

			if ($c eq '&') { $new .= '&amp;'; } 
			elsif ($c eq '>') { $new .= '&gt;'; }
			elsif ($c eq '<') { $new .= '&lt;'; }
			elsif ($c eq '"') { $new .= '&quot;'; }
			elsif (ord($c) ==0 || ord($c) == 18) { $new .= ''; }
			else { $new .= $c; }
			# $new .= $c;
			}
		}

#	print STDERR $new."\n";

	return($new);
}


sub xml_dcode
{
	my ($str) = @_;

	return($str);
}



#sub save_briefcase
#{
#	my ($USERNAME, $NAME, $BUFFER) = @_;
#	$NAME =~ s/[\W| ]+/_/g;
#	open F, ">".&ZOOVY::resolve_userpath($USERNAME)."/$NAME.briefcase";
#	print F $BUFFER;
#	close F;
#}


#sub list_briefcases
#{
#  my ($USERNAME) = @_;
#	opendir D, &ZOOVY::resolve_userpath($USERNAME);
#	my $file = '';
#	my @ar;
#	while ($file = readdir(D)) {
#		if ($file =~ /\.briefcase$/) {
#			$file =~ s/\.briefcaseb$//g;
#			push @ar, $file;
#			}
#		}
#	return(@ar);
#}
#
#sub delete_briefcase
#{
# my ($USERNAME, $NAME) = @_;
# $NAME =~ s/[\W| ]+/_/g;
# unlink &ZOOVY::resolve_userpath($USERNAME)."/$NAME.briefcase"; 
#}
#
#sub fetch_briefcase {
#	my ($USERNAME, $NAME) = @_;
#
#	my $BUFFER = "";
#	$NAME =~ s/[\W| ]+/_/g;
#	open F, "<".&ZOOVY::resolve_userpath($USERNAME)."/$NAME.briefcase";
#	$/ = undef; $BUFFER = <F>; $/ = "\n";
#	close F;
#	
#	return $BUFFER;
#}
#
#
##sub import_ogs {
#	my ($USERNAME, $BUFFER, $DESTRUCTIVE) = @_;
#	my $RESULT = "";
#	my @ar = ();
#
#	require ZWEBSITE;
##	print STDERR "import_ogs running buffer is: [$BUFFER]\n";
#
#	if ($BUFFER =~ /\<content\>(.*)\<\/content\>/si)
#     {
#      # now take the contents between the <content> tags
#      $BUFFER = $1;
#
#      # insert some crap at the end!
#      $BUFFER .= "crap";
#      # now split on the </path> tags to get an array of paths
#		@ar = split(/\<\/og\>/is,$BUFFER);
#      # remove the last element, because it ought to be null anyway 
#      pop @ar;
#      if (scalar(@ar)<1) { $RESULT = "No Option Groups Found!\n"; }
#      # now get ready to load.
#
###  this would delete all OGs which is probably NOT what we want to do
###  instead lets just leave the ones that are there, there and then
###  overwrite the rest.
#	if ($DESTRUCTIVE)
#		{
##		print STDERR "I'm feeling destructive today..\n";
#		foreach my $og (split(',',&ZWEBSITE::fetch_ogs_by_merch($USERNAME)))
#			{ &ZWEBSITE::delete_og($USERNAME,$og); }
#		}
#
##		print STDERR "We have: ".scalar(@ar)." ogs\n";
#      foreach my $og (@ar) {
#         if ($og =~ /\<og.*?name=\"(.*?)\".*?\>(.*?)$/is) {
#				my $name = $1;
#				my $contents = $2;
##				print STDERR "saving OG [$name] contents: [$contents]\n";
#				$name =~ s/.*"(.*?)".*/$1/is;
#				$name =~ s/ /_/g;
#				&ZWEBSITE::save_og($USERNAME,$name,$contents);
##				print STDERR "Saved OG $name\n";
#				}
#         }
#
#     } else {
#      $RESULT = "Missing <Content> Tags!\n";
#     }
#
#	# first thing, check the contents.
##	print STDERR "Finished!!!\n";
#	return($RESULT);
#}
#

#sub import_customers {
#	my ($USERNAME, $BUFREF) = @_;
#
#	require CUSTOMER;
#	require XML::Parser;
#	require XML::Parser::EasyTree;
#	require ZTOOLKIT;
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
##	print STDERR "Running ZWEBAPI::import_customers\n";
#
#	${$BUFREF} .= "crap";
#	# if we split on the </customer> tag, then we know everything before it is a
#	# valid customer (at least anything after the <customer xxx> tag)
#	my @ar = split(/\<\/customer\>/i,${$BUFREF});
#	# always remove the last element of the ARRAY since nothing good can come
#	# after a </customer> tag
#	pop(@ar);
#	my $parse = new XML::Parser(Style=>'EasyTree');
#	
#	foreach my $CUSTOMER (@ar) {
##		print STDERR "Starting CUSTOMER length=[".length($CUSTOMER)."] - [$CUSTOMER]\n";
#
#		$CUSTOMER .= "</customer>"; # Have to add the end customer tag back on so its valid XML
#		my $tree = $parse->parse($CUSTOMER);
## 	don't know why this is here
##		my %merch_customers = &CUSTOMER::list_customers_by_id($USERNAME);
#		foreach my $roottaghash (@{$tree}) {
#			my $rootname = $roottaghash->{'name'};
#			my $rootcontent = $roottaghash->{'content'};
#			my $rootattrib = $roottaghash->{'attrib'};
#
#			### Verify we are looking at a customer record
#			if ($rootname eq 'customer') {
#				my $CUSTOMER_ID = $rootattrib->{'id'};
#
#
#				my $OLD_EMAIL = &CUSTOMER::resolve_email($USERNAME,$CUSTOMER_ID);
## Need to get this working
##				if (not &ZTOOLKIT::iskey(\%merch_customers,$CUSTOMER_ID)) { next; }
#				my ($LIKESPAM,$FULLNAME,$PASSWORD,$EMAIL,$meta_ref);
#
#				## look through each customer tag hash, the customer tag hash contains
#				## upper level information which is inserted into the actual CUSTOMER record.
#				foreach my $customertaghash (@{$rootcontent}) {
#					next unless defined($customertaghash->{'name'});
#					my $name = $customertaghash->{'name'};
#					my $attrib = $customertaghash->{'attrib'};
#					my $simple_contents;
#					if (defined $customertaghash->{'content'}[0]{'content'}) {
#						$simple_contents = $customertaghash->{'content'}[0]{'content'};
#					}
#					else {
#						$simple_contents = '';
#					}
#					
#					if ($name eq 'email') { $EMAIL = $simple_contents; }
#					elsif ($name eq 'likespam') { $LIKESPAM = $simple_contents; }
#					elsif ($name eq 'fullname') { $FULLNAME = $simple_contents; }
#					elsif ($name eq 'password') { $PASSWORD = $simple_contents; }
#					elsif ($name eq 'email') { $EMAIL = $simple_contents; }
#					elsif ($name eq 'meta') {
#						$meta_ref = {};
#						&CUSTOMER::thawhash(&ZOOVY::dcode($simple_contents),$meta_ref);
#					}
#
#
#					# I would have documented more of this, but I'm surprised it works myself, so
#					# I don't think any attempt would be all that useful.  I call this section
#					# "reference hell", or more jocularly "pointer to reference hell" -AK 
#					### NOTE: the comment above does me no fucking good. -BH
#					elsif ($name eq 'shipping') {
#						foreach my $shiptaghash (@{$customertaghash->{'content'}}) {
#							next unless defined($shiptaghash->{'name'});
#							my $shipattrib = $shiptaghash->{'attrib'};
#							next unless defined($shipattrib->{'id'});
#							my $shipname = $shiptaghash->{'name'};
#							my $shipcontent = $shiptaghash->{'content'};
#
#							if ($shipname eq 'code') {
#								my $mutha = {};
#								foreach my $subshiptaghash (@{$shipcontent}) {
#									next unless defined($subshiptaghash->{'name'});
#									my $subshipname = $subshiptaghash->{'name'};
#									if (defined $subshiptaghash->{'content'}[0]{'content'}) {
#										$mutha->{$subshipname} = $subshiptaghash->{'content'}[0]{'content'};
#									}
#									else {
#										$mutha->{$subshipname} = '';
#									}
#								}
#
#								# Freeze the hash here
#								delete $mutha->{'ship_email'};
#								my $frozenmutha = &CUSTOMER::freezehash($mutha);
#								# Store the info with the customer here
#								&CUSTOMER::save_ship_info($USERNAME,$MID,$CUSTOMER_ID,$shipattrib->{'id'},$frozenmutha);
#							}
#						}
#					} # end of ($name eq 'shipping')
#					elsif ($name eq 'billing') {
#						foreach my $billtaghash (@{$customertaghash->{'content'}}) {
#							next unless defined($billtaghash->{'name'});
#							my $billattrib = $billtaghash->{'attrib'};
#							next unless defined($billattrib->{'id'});
#							my $billname = $billtaghash->{'name'};
#							my $billcontent = $billtaghash->{'content'};
#							if ($billname eq 'code') {
#								my $mutha = {};
#								foreach my $subbilltaghash (@{$billcontent}) {
#									next unless defined($subbilltaghash->{'name'});
#									my $subbillname = $subbilltaghash->{'name'};
#									if (defined $subbilltaghash->{'content'}[0]{'content'}) {
#										$mutha->{$subbillname} = $subbilltaghash->{'content'}[0]{'content'};
#									}
#									else {
#										$mutha->{$subbillname} = '';
#									}
#								}
#								# Freeze the hash here
#								my $frozenmutha = &CUSTOMER::freezehash($mutha);
#								# Store the info with the customer here
#								&CUSTOMER::save_bill_info($USERNAME,$MID,$CUSTOMER_ID,$billattrib->{'id'},$frozenmutha);
#							}
#						}
#					} # end of ($name eq 'billing')
#				} # End of loop through all customer tags
#
##				print STDERR "ID=[$CUSTOMER_ID] LIKESPAM=[$LIKESPAM] FULLNAME=[$FULLNAME] PASSWORD=[$PASSWORD] EMAIL=[$EMAIL]\n";
#
#				if ($CUSTOMER_ID == -1)		
#					{
#					&CUSTOMER::delete_customer($USERNAME,$EMAIL);
#					next; # we can stop now since we have deleted this customer.#
#					}#
#
#
#				## if the customer id is 0 then we create a new record
#				if ($CUSTOMER_ID == 0) {
#					&CUSTOMER::new_customer($USERNAME,$EMAIL,$PASSWORD,$LIKESPAM);
#					$OLD_EMAIL = $EMAIL;
#				} ##  end of if new customer#
#
#
#
#				########################################################
#				# Save off customer information
#				&CUSTOMER::update_customer($USERNAME, $OLD_EMAIL, $PASSWORD, 'DEFAULT', 'DEFAULT', $LIKESPAM, $FULLNAME);
#				&CUSTOMER::save_meta_from_hash($USERNAME,$OLD_EMAIL,$meta_ref);
#				# Needs to happen LAST!
#				&CUSTOMER::change_email($USERNAME,$OLD_EMAIL,$EMAIL);
#			} # End of if its a customer tag
#		} # End of root $tree loop
#	} 
#}

1;

##### LINE OF DEPRECATION


