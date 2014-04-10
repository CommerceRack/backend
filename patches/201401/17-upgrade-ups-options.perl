#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;

#$USERNAME |= $ARGV[0];
print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

## get a list of partitions
foreach my $PRT ( @{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
	print "PRT: $PRT\n";

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
   if (my $UPSAPI_OPTIONS = $webdbref->{'upsapi_options'}) {
      my %upsapi_config = %{&ZTOOLKIT::parseparams($webdbref->{'upsapi_config'})};
      $upsapi_config{'.product'} = ($UPSAPI_OPTIONS&2)?1:0;
      $upsapi_config{'.multibox'} = ($UPSAPI_OPTIONS&4)?1:0;
      $upsapi_config{'.residential'} = ($UPSAPI_OPTIONS&8)?1:0;
      $upsapi_config{'.validation'} = ($UPSAPI_OPTIONS&16)?1:0;
      $upsapi_config{'.use_rules'} = ($UPSAPI_OPTIONS&32)?1:0;
      $upsapi_config{'.disable_pobox'} = ($UPSAPI_OPTIONS&64)?1:0;                                                                                             
		$webdbref->{'upsapi_config'} = &ZTOOLKIT::buildparams(\%upsapi_config,1);
		delete $webdbref->{'upsapi_options'};
      print "SAVE\n";
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		}

	}


