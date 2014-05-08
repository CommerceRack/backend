package BATCHJOB::EXPORT;

use strict;

use Data::Dumper;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;
require NAVCAT;
require SITE;
require PRODUCT::FLEXEDIT;
require POGS;
use Text::CSV_XS;



#
## ADVANCED EXPORT EXAMPLE:
# @START
# @seller-id|%TEXT=xyz
# @gtin|%TRY=zoovy:prod_upc,zoovy:prod_ean
# @isbn|zoovy:prod_isbn
# @mfg-name|zoovy:prod_mfg
# @mfg-part-number|zoovy:prod_mfg
# @description|zoovy:prod_desc
# @reserved|
# @END
#
#sub parse_headers {
#	my ($fields,$ignore) = @_;
#
#	my $attribsref = [];
#	my @MSGS = ();
#	my @LINES = ();
#	$fields =~ s/^[\s]+//gs;	# strip leading whitespace
#	$fields =~ s/[\s]+$//gs;	# strip trailing whitespace
#	if (substr($fields,0,1) eq '@') {
#		## advanced import
#		@LINES = split(/[\n\r]+/,$fields);
#		my $linecount = 1;
#		foreach my $line (@LINES) {
#			if (substr($line,0,1) ne '@') { push @MSGS, "ERROR|Line[$linecount] '$line' does not being with an \@"; }
#			if ($line =~ /[\s\t]+$/) { push @MSGS, "ERROR|Line[$linecount] '$line' has one or more trailing spaces or tabs in the header"; }
#			$linecount++;
#			}
#
#		if ($LINES[0] ne '@START') {
#			push @MSGS, "ERROR|Advanced imports must start with the line \@START and end with \@END";
#			}
#		else {
#			shift @LINES;	# remove the start line
#			}
#
#		while ((scalar(@LINES)>0) && ($LINES[scalar(@LINES)-1] eq '')) {
#			## remove trailing blank lines.
#			pop @LINES;	
#			}
#
#		if ($LINES[scalar(@LINES)-1] ne '@END') {
#			push @MSGS, "ERROR|Advanced imports must start with the line \@START and end with \@END";
#			}
#		else {
#			pop @LINES;	# remove the @END line
#			}
#		}
#	else {
#		## non advanced import zoovy:prod_name, etc.
#		@LINES = split(/[\n\r\,\t]+/,$fields);
#		foreach my $line (@LINES) {
#			$line =~ s/^[\s]+//gs;	# strip leading whitespace
#			$line =~ s/[\s]+$//gs;	# strip trailing whitespace
#			}
#		unshift @LINES, "%SKU";
#		}
#
#	return(\@LINES,\@MSGS);
#	}


##
## these methods should be included in the header of every report::module
##
sub new { 
	my ($class,$bj) = @_; 
	my $self = {}; 
	$self->{'*BJ'} = $bj;		## pointer to the batch job object
	bless $self, $class; 

	return($self); 
	}


sub bj { return($_[0]->{'*BJ'}); }
sub vars { return($_[0]->{'%vars'}); }
sub prt { return($_[0]->bj()->prt()); }

##
## pretty self explanatory. updates the progress meter.
##
sub progress {
	my ($self, $records_done, $records_total, $msg) = @_;

	print STDERR "$records_done/$records_total: $msg\n";
	my ($bj) = $self->bj();
	if (defined $bj) {
		$bj->update(
			RECORDS_DONE=>$records_done,
			RECORDS_TOTAL=>$records_total,
			STATUS=>'RUNNING',
			STATUS_MSG=>$msg,
			);
		}
	}



###########################################################################
##
##
##
sub run {
	my ($self, $bj) = @_;

	if (not defined $bj) {
		$bj = $self->{'*BJ'};
		$bj->nuke_slog();			## we might run a csv more than once. so lets clear it out.
		}

	my ($USERNAME) = $bj->username();

	my $LUSERNAME = $bj->lusername();
	my $PRT = $bj->prt();
	my $vars = $bj->vars();

	my ($VERB,$EXPORT) = $bj->execverb();

	# my $EXPORT = uc($vars->{'EXPORT'});
	$EXPORT =~ s/[^A-Z0-9\_\-]+//g;
	if ($bj->version()<201346) {
		if ((not defined $EXPORT) || ($EXPORT eq '')) {
			$EXPORT = 'PRODUCTS'; 
			}
		}

	$self->{'%vars'} = $vars;

	# print "FILENAME: $FILENAME ($FILEPATH)\n";
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$bj->progress(0,0,"Starting .. ");

	my ($TMPFILEPATH,$FILENAME,$FILETYPE,$RESULT) = (undef,undef);
	
	print "EXPORT: $EXPORT\n";

	if ($EXPORT eq 'PRODUCTS') {
		require BATCHJOB::EXPORT::PRODUCTS;
		$FILENAME = sprintf("job_%d_product_export_%s.csv",$bj->id(),&ZTOOLKIT::pretty_date(time(),3));
		($TMPFILEPATH) = BATCHJOB::EXPORT::PRODUCTS::generate($bj);
		$RESULT = sprintf("Finished");
		$FILETYPE = 'CSV';
		}
	elsif ($EXPORT eq 'PAGES') {
		require BATCHJOB::EXPORT::PAGES;
		$FILENAME = sprintf("job_%d_%s-pages.json",$bj->id(),&ZTOOLKIT::pretty_date(time(),3));
		($TMPFILEPATH) = BATCHJOB::EXPORT::PAGES::generate($bj);
		$RESULT = sprintf("Finished pages generation.");
		$FILETYPE = 'JSON';
		}
	elsif ($EXPORT eq 'RULES') {
		require BATCHJOB::EXPORT::RULES;
		$FILENAME = sprintf("job_%d_%s-rules.json",$bj->id(),&ZTOOLKIT::pretty_date(time(),3));
		($TMPFILEPATH) = BATCHJOB::EXPORT::RULES::generate($bj);
		$RESULT = sprintf("Finished pages generation.");
		$FILETYPE = 'CSV';
		}
	else {
		warn "UNKNOWN MODULE:$EXPORT\n";		
		}

	if ($TMPFILEPATH) {
		require LUSER::FILES;
		my ($lf) = LUSER::FILES->new($bj->username());
	
		my ($guid) = $lf->add('file'=>$TMPFILEPATH,'type'=>$FILETYPE,'filename'=>$FILENAME,'guid'=>$bj->guid(),'overwrite'=>1,'EXPIRES_GMT'=>(time()+30*86400));
		$bj->title($FILENAME);
		}

   &DBINFO::db_user_close();
	return('SUCCESS',$RESULT);
	}




1;

