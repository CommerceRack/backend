package BATCHJOB::UTILITY::PRODUCT_SALESRANK;

##
## goes through CUSTOMER_REVIEWS table and updates zoovy:prod_salesrank for products which have reviews
## author: bh 9/25/09
## ticket: 194148 cypherstyles.
##

use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use PRODUCT;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	## standard preamble for batchjob/utilities.
	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	$bj->progress(0,0,"Getting list of products w/reviews");

	## lets go to the database, get a list of products and create an average review
	##	we let mysql do the heavy lifting here. 
	my @RECORDS = ();
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	## only add salesrank for APPROVED reviews
	#my $pstmt = "select PID,((RATING*10) div 10) as RATING from CUSTOMER_REVIEWS where MID=$MID /* $USERNAME */ group by PID;";
	my $pstmt = "select PID,((RATING*10) div 10) as RATING from CUSTOMER_REVIEWS where MID=$MID /* $USERNAME */ and APPROVED_GMT > 0 group by PID;";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($PID,$RATING) = $sth->fetchrow() ) {
		push @RECORDS, [ $PID, $RATING ];
		}	
	$sth->finish();
	

	## setup some more standard stuff, what record are we on ($reccount) .. how many will we do ($rectotal)
	my $reccount = 0;
	my $rectotal = scalar(@RECORDS);

	## now lets go through each record. 
	foreach my $set (@RECORDS) {
		my $PID = $set->[0];
		my $RATING = $set->[1];

		## get the product from the database 
		my ($P) = PRODUCT->new($USERNAME,$PID,'create'=>0);
		next if (not defined $P);

		if ($P->fetch('zoovy:prod_salesrank') == $RATING) {
			## rating is unchanged, don't do anything!
			}
		else {
			## only update the prod_salesrank if it's changed. 
			$P->store('zoovy:prod_salesrank',$RATING);
			$P->save();
			}
		
		## increment which record we're on ($reccount), for the STATUS TO THE USER .. 
		##	this will cause the little progress meter to move.
		## 	but only update the progress meter ever 10 records starting at record #1.
		##		we do this using modulo or % .. which returns a remainder.
		##		10 % 3 == 1  
		##		9 % 3 == 0
		## 	8 % 3 == 2 
		## remember remainders in division.. we covered them in 3rd grade right after the alligators.
		if ((++$reccount % 10)==1) {
			$bj->progress($reccount,$rectotal,"Processing products");
			}
	   }
	$bj->progress($rectotal,$rectotal,"Finished updating salesrank");
	&DBINFO::db_user_close();


	return(undef);
	}

1;
