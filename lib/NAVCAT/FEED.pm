package NAVCAT::FEED;

use strict;

use lib "/backend/lib";
require NAVCAT;


#####################################
##
## designed to work with:
##		FROOGLE_CAT <-- umm.. is 1:22am .. this doesn't exist!
##		YSHOP_CAT
##		DEALTIME_CAT
##		BIZRATE_CAT
##		NEXTAG
##		MYSIMON_CAT
##
##	OPTIONS (bitwise)
##		1 = skip hidden!
##		2 = check inventory
##		4 = skip lists
##
## RESULT:
##		(ncprettyref,$ncprodref,$ncref) 
##   my %ncpretty = ();			# key=safe, val=breadcrumb of pretty
##   my %ncprodref = ();			# key=product id, val=which safe name it belongs to
##   my %ncmapref = ();			# key=product id, val=the $METAKEY for that product
######################################
#sub matching_navcats {
#   # my ($USERNAME,$METAKEY,$OPTIONS,$ROOT,$PRT) = @_;
#	my ($USERNAME,$METAKEY) = @_;
#
#	if (not defined $ROOT) { $ROOT = '.'; }
#	if (not defined $OPTIONS) { $OPTIONS = 0; }
#
#   my %ncpretty = ();			# key=safe, val=breadcrumb of pretty
#   my %ncprodref = ();			# key=product id, val=which safe name it belongs to
#   my %ncmapref = ();			# key=product id, val=the $METAKEY for that product
#
#	my ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT,root=>$ROOT);
#
#   foreach my $safe (sort $NC->paths($ROOT)) {
#      my ($pretty, $child, $products, $sortstyle,$metaref) = $NC->get($safe);
#		my $skip = 0;
#		
#		if ((not defined $METAKEY) || ($METAKEY eq '')) {
#			## no metakey defined, keep going
#			}
#      elsif ((($OPTIONS & 1)==1) && (substr($pretty,0,1) eq '!')) {
#			# skip hidden categories.
#			$skip =1;
#			}
#      elsif ((($OPTIONS & 4)==4) && (substr($safe,0,1) eq '$')) {
#			# skip lists.
#			$skip =2;
#			}
#		elsif (substr($safe,0,1) eq '*') {
#			## skip pages.
#			$skip =3;
#			}
#		elsif (($METAKEY eq 'EBAYSTORE_CAT') && ($metaref->{$METAKEY} eq '0')) {
#			## NOTE: METAKEY 0 is used by ebay stores to represent OTHER - but is invalid for all else.
#			}
#		elsif ($metaref->{$METAKEY} eq '') {
#			if ($METAKEY eq 'GOOGLEBASE') {
#				## googlebase always gets submitted, even if no product type is set.
#				}
#			else {
#				## skip this for "category not set" value
#				$skip = 4;
#				}
#			}
#		else {
#			## okay we're going to include this!
#			}
#
#		next if ($skip);
#
#
#      $ncpretty{$safe} = &path_breadcrumb($NC,$safe);
#
#      foreach my $prod (split(/,/,$products)) {
#         if (not defined $ncprodref{$prod}) {
#            ## doesn't exist yet.
#            $ncprodref{$prod} = $safe;
#            $ncmapref{$prod} = $metaref->{$METAKEY};
#				}
#         elsif (length($ncprodref{$prod}) < length($safe)) {
#            ## legnth of existign is less than current
#            $ncprodref{$prod} = $safe;
#            $ncmapref{$prod} = $metaref->{$METAKEY};
#            }
#         }
#      }
#	undef $NC;
#
#
#	##  check inventory
#   if (($OPTIONS & 2)==2) {
#      my @PIDS = keys %ncprodref;
#
#      my ($invref) = &INVENTORY::fetch_incrementals($USERNAME,\@PIDS,undef,1+8);
#      foreach my $pid (@PIDS) {
#         if ($invref->{$pid} == 0) {
#            delete $ncprodref{$pid};
#            delete $ncmapref{$pid};
#            }
#         }
#      }
#
#
#   return(\%ncpretty,\%ncprodref,\%ncmapref);
#   }

#####################################
##
##
######################################
sub path_breadcrumb {
   my ($NC, $SAFE) = @_;

   my $OUTPUT = '';
	if (substr($SAFE,0,1) eq '$') {
		($OUTPUT) = split(/\n/,$NC->get($SAFE));
		return($OUTPUT);
		}

   my @pathparts = split (/\./, $SAFE);
   shift @pathparts;    # There's nothing before the first dot

   my $pathtmp = '';

   foreach my $pathpart (@pathparts) {
      $pathtmp = $pathtmp . '.' . $pathpart;
      (my $name, undef, undef, undef) = $NC->get($pathtmp);
      $name =~ s/^\!//gs;
      $OUTPUT .= " > $name";
      }
   $OUTPUT = substr($OUTPUT,3);
   return $OUTPUT;
	} ## end sub path_breadcrumb



1;
