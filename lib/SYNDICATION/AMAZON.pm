package SYNDICATION::AMAZON;

use strict;



sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	# $so->set('.url','site://'.$so->profile().'-nextag.txt');

	$so->set('.url','null');
	$so->pooshmsg("HINT|+Due to how the Zoovy system interacts with the Amazon API - this tool may have unpredictable results");

	bless $self, 'SYNDICATION::AMAZON';  
	return($self);
	}


sub so { return($_[0]->{'_SO'}); }


sub preflight {
	my ($self, $lm) = @_;

	my ($USERNAME) = $self->so()->username();
	system("/httpd/servers/amazon/sync.pl user=$USERNAME");
	$lm->pooshmsg("END|+ran amazon sync.pl");
	return();
	}



sub product_validate {
	my ($USERNAME,$P) = @_;

	my $lm = LISTING::MSGS->new($USERNAME);

	require SYNDICATION;
	require XML::Smart;
	my ($so) = SYNDICATION->new($USERNAME,'AMZ',PRT=>'0');
	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,$so->prt());
	$userref->{'*SO'} = $so;
	$userref->{'*msgs'} = $lm;

	my ($thesref) = &AMAZON3::fetch_thesaurus_detail($userref);
	# my ($ncprettyref,$ncprodref,$ncref) = &NAVCAT::FEED::matching_navcats($USERNAME,'AMAZON_THE');

	my ($RELATIONS) = &AMAZON3::relationships($P);
	my $ME = (shift @{$RELATIONS})->[0];	## the first element is our descriptor

	my %CACHED_PRODUCTS = ();
	my @TODO = ();
	push @TODO, [ $P->pid(), $P ];
	if ($ME eq 'BASE') {
		}
	elsif ($ME eq 'CHILD') {
		$lm->pooshmsg("ISE|Internal logic error - panel not valid for CHILD");
		}
	elsif ($ME eq 'XFAMILY') {
		foreach my $REL (@{$RELATIONS}) {
			if ($REL->[0] eq 'XPRODUCT') {
				## with XFAMILY we send grandparents->variation (parent->child->variation) so this is ignored intentionally.
				}
			elsif ($REL->[0] eq 'XSKU') {
				my ($PID) = &PRODUCT::stid_to_pid($REL->[1]);
				my $xP = $CACHED_PRODUCTS{$PID};
				if (not defined $xP) { $xP = $CACHED_PRODUCTS{$PID} = PRODUCT->new($USERNAME,$REL->[1]); }
				push @TODO, [ $REL->[1], $xP ];
				}
			}
		}
	elsif ($ME eq 'CONTAINER') {
		foreach my $REL (@{$RELATIONS}) {
			if ($REL->[0] eq 'VARIATION') {  ## variations
				push @TODO, [ $REL->[1], $P ];
				}
			elsif ($REL->[0] eq 'CHILD') {
				push @TODO, [ $REL->[1], $P ];
				}
			elsif ($REL->[0] eq 'ORPHAN') {
				push @TODO, [ $REL->[1], $P ];
				}
			}
		}
	else {
		$lm->pooshmsg("ISE|+Unknown relationship perspective:$ME (was not processed)");
		}
	
	if ($lm->can_proceed()) {
		foreach my $set (@TODO) {
			my ($SKU, $P) = @{$set};
			my $slm = LISTING::MSGS->new($USERNAME);
			$slm->pooshmsg("TITLE|+$SKU Starting product feed");
			($slm,my $prodxml) = &AMAZON3::create_skuxml($userref,$SKU,$P,'@xml'=>[],'*LM'=>$slm,'%THESAURUSREF'=>$thesref);
			$slm->pooshmsg("XML|+".join("",@{$prodxml}));
			use Data::Dumper;
			if ($slm->has_win()) { $slm->pooshmsg('SUCCESS|+Will Be Sent'); }
			elsif ($slm->had('ISE')) { $slm->pooshmsg('ERROR|+Internal Application Error'); }
			elsif ($slm->had('STOP')) { $slm->pooshmsg('WARN|+Not Eligible for Send'); }
			elsif ($slm->had('PAUSE')) { $slm->pooshmsg('WARN|+Not Eligible for Send'); }
			elsif ($slm->has_failed()) { $slm->pooshmsg('ERROR|+Not Sent due to Errors'); }
			else { $slm->pooshmsg('ERROR|+Unknown Result'); }
			$lm->merge($slm,'sku'=>$SKU);

			if ($slm->has_win()) {
				my $ilm = LISTING::MSGS->new($USERNAME);
				$ilm->pooshmsg("TITLE|+$SKU Starting images feed");
				($ilm,my $imgxml) = &AMAZON3::create_imgxml($userref,$SKU,$P,'@xml'=>[],'*LM'=>$ilm);
				$ilm->pooshmsg("XML|+".join("",@{$imgxml}));
				my ($pretty) = 'Unknown Result';
				if ($ilm->has_win()) { $ilm->pooshmsg('SUCCESS|+Images Will Be Sent'); }
				elsif (my $msgref = $ilm->had('ISE')) { $ilm->pooshmsg(sprintf('ERROR|+Internal Server Error %s',$msgref->{'+'})); }
				elsif ($msgref = $ilm->had('STOP')) { }
				elsif ($msgref = $ilm->had('PAUSE')) { }
				elsif ($ilm->has_failed()) { $ilm->pooshmsg('ERROR|+Images Not Sent due to Errors'); }
				else { $ilm->pooshmsg('ERROR|+Unknown Result or Status'); }
				$lm->merge($ilm,'sku'=>$SKU);

				my $plm = LISTING::MSGS->new($USERNAME);
				$plm->pooshmsg("TITLE|+$SKU Starting pricing feed");
				($plm,my $pricexml) = &AMAZON3::create_pricexml($userref,$SKU,$P,'@xml'=>[],'*LM'=>$plm);
				$plm->pooshmsg("XML|+".join("",@{$pricexml}));
				($pretty) = 'Unknown Result';
				if ($plm->has_win()) { $plm->pooshmsg('SUCCESS|+Prices Will Be Sent'); }
				elsif (my $msgref = $plm->had('ISE')) { $plm->pooshmsg(sprintf('ERROR|+Internal Server Error %s',$msgref->{'+'})); }
				elsif ($msgref = $plm->had('STOP')) { }
				elsif ($msgref = $plm->had('PAUSE')) { }
				elsif ($plm->has_failed()) { $plm->pooshmsg('ERROR|+Prices Not Sent due to Errors'); }
				else { $plm->pooshmsg('ERROR|+Unknown Result or Status'); }
				$lm->merge($plm,'sku'=>$SKU);

				my $rlm = LISTING::MSGS->new($USERNAME);
				$rlm->pooshmsg("TITLE|+$SKU Starting relations feed");
				($rlm,my $relxml) = &AMAZON3::create_relationxml($userref,$SKU,$P,'@xml'=>[],'*LM'=>$rlm);
				$rlm->pooshmsg("XML|+".join("",@{$relxml}));
				if ($rlm->has_win()) { $rlm->pooshmsg('SUCCESS|+Relations Will Be Sent'); }
				elsif (my $msgref = $rlm->had('ISE')) { } # $rlm->pooshmsg(sprintf('ERROR|+Internal Server Error %s',$msgref->{'+'})); }
				elsif ($msgref = $rlm->had('PAUSE')) { } # $rlm->pooshmsg(sprintf('ERROR|+Stopped (reason: %s)',$msgref->{'+'})); }
				elsif ($msgref = $rlm->had('STOP')) { } # $rlm->pooshmsg(sprintf('ERROR|+Stopped (reason: %s)',$msgref->{'+'})); }
				elsif ($rlm->has_failed()) { $rlm->pooshmsg('ERROR|+Relations Not Sent due to Errors'); }
				else { $rlm->pooshmsg('ERROR|+Unknown Result or Status'); }
				$lm->merge($rlm,'sku'=>$SKU);
				}
			else {
				}
			}
		}
	return($lm);
	}

1;

