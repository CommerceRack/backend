package REPORT::CUSTOMER;

use strict;

use lib "/backend/lib";
require DBINFO;
require CUSTOMER;
use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


##
## REPORT: SALES
##	PARAMS: 
##		period
##			start_gmt
##			end_gmt
##

sub init {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();

	## META data
	$meta->{'title'} = 'Customer Report';
	$r->{'@BODY'} = [];

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'CID', hidden=>1, },
		{ id=>1, 'name'=>'Email', type=>'CHR', link=>'https://www.zoovy.com/biz/manage/customer/?VERB=EDIT&CID=%%0&EMAIL=', target=>'_blank' },
		{ id=>2, 'name'=>'FirstName', type=>'CHR', },
		{ id=>3, 'name'=>'LastName', type=>'CHR', },
		{ id=>4, 'name'=>'Newsletter', type=>'NUM', },
		{ id=>5, 'name'=>'Created', type=>'YDT', },
		{ id=>6, 'name'=>'Modified', type=>'YDT', },
		{ id=>7, 'name'=>'OrganizationID', type=>'NUM', },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Customer Count', type=>'CNT', src=>0 },
		];

	return();
	}



###################################################################################
##
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $PRT = $r->prt();
	my $MID = $r->mid();

	my $udbh =&DBINFO::db_user_connect($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
	my $pstmt = "select CID, EMAIL, FIRSTNAME, LASTNAME, NEWSLETTER, CREATED_GMT,MODIFIED_GMT, ORGID from $CUSTOMERTB where MID=$MID and PRT=$PRT";
	print STDERR $pstmt."\n";
	if ($meta->{'.mode'} eq 'ALL') {
		## shows all customers
		}
	elsif ($meta->{'.mode'} eq 'NEWSLETTER') {
		## shows all customers who have a LIKES_SPAM set to 1
		$pstmt .= " and NEWSLETTER>0";
		}
	else {
		warn "Unknown mode: $meta->{'.mode'}";
		}

#	if (defined $SINCE) {
#		$pstmt .= " and MODIFIED>".&ZTOOLKIT::mysql_from_unixtime($SINCE+0);
#		}

	my $sth = $udbh->prepare($pstmt);
	my $rv = $sth->execute();

	my $reccount = 0;
	my $rectotal = $sth->rows();

	if (defined($rv)) {
		while ( my @ROW = $sth->fetchrow() ) { 
			push @{$r->{'@BODY'}}, \@ROW;
			$reccount++;
			if (($reccount % 3000)==0) {
				$r->progress($reccount,$rectotal,"Downloading Customers from Database");
				}
			}
		}
	&DBINFO::db_user_close();

	$r->progress($reccount,$rectotal,"Finished building Customer export");
	}


sub cleanup {
	}


1;

