package TOXML::ANNOTATE;

use strict;

require YAML::Syck;
use lib "/backend/lib";
require ZTOOLKIT;
require ZOOVY;

##
##
sub add_note {
	my ($USERNAME, $FORMAT, $DOCID, $LUSER, $ACTION, %options) = @_;

	## strip leading ~
	if (substr($DOCID,0,1) eq '~') { $DOCID = substr($DOCID,1); }

	my $ref = undef;
	my $path = &ZOOVY::resolve_userpath($USERNAME).'/TOXML';
	mkdir($path);
	chmod(0755,$path);

	my $filepath = $path.'/'.$FORMAT.'+'.lc($DOCID).'.yaml';
	if (-f $filepath) {
		$ref = eval { YAML::Syck::LoadFile($filepath); };
		if (not defined $ref) {
			}
		}

	if (not defined $ref) {
		$ref->{'CREATED'} = &ZTOOLKIT::pretty_date(time(),2);
		$ref->{'@REVISIONS'} = [];
		}


	$ref->{'VERSION'}++;	
	push @{$ref->{'@REVISIONS'}}, { 
		V=>int($ref->{'VERSION'}), CREATED=>ZTOOLKIT::pretty_date(time(),2), LUSER=>$LUSER, ACTION=>$ACTION, %options
		};
	YAML::Syck::DumpFile($filepath,$ref);
	chown $ZOOVY::EUID,$ZOOVY::EGID, $filepath;	
	}


##
## *REQUIRED* options:
##		TECH=>zoovy employee/contractor
##		V=>version #
##		DIGEST=>
##
##	*RECOMMENDED*
##		NOTES=>""
##		TICKET=>""
##		WARRANTY=>""
##
## *OTHER IDEAS*
##		DO_BACKUP=>1 becomes BACKUP=>""
##
sub sign {
	my ($USERNAME,$FORMAT,$DOCID, %options) = @_;
	
	## 
	my $ref = &TOXML::ANNOTATE::get_log($USERNAME,$FORMAT,$DOCID);
	if (not defined $ref->{'@TESTED'}) {
		$ref->{'@TESTED'} = [];
		}
	## grab the last revision
	my $rev = undef;
	if (scalar(@{$ref->{'@REVISIONS'}})>0) {
		$rev = $ref->{'@REVISIONS'}->[scalar(@{$ref->{'@REVISIONS'}})-1];
		}

	if (defined $rev) {
		## so we can now sign the last revision

		my $path = &ZOOVY::resolve_userpath($USERNAME).'/TOXML';
		mkdir($path);
		chmod(0755,$path);

		my $filepath = $path.'/'.$FORMAT.'+'.lc($DOCID).'.yaml';
		YAML::Syck::DumpFile($filepath,$ref);
		chown $ZOOVY::EUID,$ZOOVY::EGID, $filepath;	
		}

	}


##
##
sub get_log {
	my ($USERNAME,$FORMAT,$DOCID) = @_;

	## strip leading ~
	if (substr($DOCID,0,1) eq '~') { $DOCID = substr($DOCID,1); }
   if ($FORMAT eq 'ZEMAIL') { $FORMAT = 'EMAIL'; }

	my $filepath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML/'.$FORMAT.'+'.lc($DOCID).'.yaml';
	my $ref = undef;
	if (-f $filepath) {
		$ref = YAML::Syck::LoadFile($filepath);
 		if (not defined $ref) {
			&ZOOVY::confess($USERNAME,"Yaml corrupt in $filepath - resetting",justkidding=>1);
			}
		}
	
	if (not defined $ref) {
		$ref->{'@REVISIONS'} = [];
		$ref->{'CREATED'} = '';
		$ref->{'VERSION'} = 0;
		}
	return($ref);
	}


sub get_last_rev {
	my ($USERNAME,$FORMAT,$DOCID) = @_;

	my $ref = &TOXML::ANNOTATE::get_log($USERNAME,$FORMAT,$DOCID);
	if (scalar(@{$ref->{'@REVISIONS'}})>0) {
		return($ref->{'@REVISIONS'}->[scalar(@{$ref->{'@REVISIONS'}})-1]);
		}
	return(undef);
	}


1;
