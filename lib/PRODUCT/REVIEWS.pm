package PRODUCT::REVIEWS;

use lib "/backend/lib";
use strict;
require ZOOVY;
require DBINFO;
require CUSTOMER;
require PRODUCT;


#mysql> desc CUSTOMER_REVIEWS;
#+-------------+-----------------------+------+-----+---------+----------------+
#| Field       | Type                  | Null | Key | Default | Extra          |
#+-------------+-----------------------+------+-----+---------+----------------+
#| ID          | int(11)               |      | PRI | NULL    | auto_increment |
#| USERNAME    | varchar(20)           |      |     |         |                |
#| MID         | int(11)               |      |     | 0       |                |
#| CUSTOMER    | varchar(65)           |      |     |         |                |
#| CID         | int(11)               |      |     | 0       |                |
#| LOCATION    | varchar(30)           |      |     |         |                |
#| PID         | varchar(20)           |      |     |         |                |
#| CREATED_GMT | int(10) unsigned      |      |     | 0       |                |
#| SUBJECT       | varchar(60)           |      |     |         |                |
#| MESSAGE     | text                  |      |     |         |                |
#| USEFUL_YES  | mediumint(8) unsigned |      |     | 0       |                |
#| USEFUL_NO   | mediumint(8) unsigned |      |     | 0       |                |
#| RATING      | tinyint(4)            |      |     | 0       |                |
#| BLOG_URL    | varchar(128)          |      |     |         |                |
#| IPADDRESS   | bigint(20)            |      |     | 0       |                |
#+-------------+-----------------------+------+-----+---------+----------------+
#15 rows in set (0.02 sec)


sub rename_product {
	my ($USERNAME,$PID,$NEWPID) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
		
	my $qtPID = $dbh->quote($PID);
	my $qtNEWPID = $dbh->quote($NEWPID);
	my $pstmt = "update CUSTOMER_REVIEWS set PID=$qtNEWPID where PID=$qtPID and MID=$MID /* $USERNAME */";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	}



sub update_review {
	my ($USERNAME,$RID,%OPTIONS) = @_;

	$OPTIONS{'ID'} = int($RID);
	$OPTIONS{'MID'} = &ZOOVY::resolve_mid($USERNAME);

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	if (defined $OPTIONS{'_NUKE_'}) {

		## added extra step to remove zoovy:prod_salesrank from product if needed
		## ie if the merchant is deleting the review and its the only review for this product, remove attrib zoovy:prod_salesrank
		## note: for some merchants, zoovy:prod_salesrank is updated nightly via app8 batch job
		my $pstmt = " select pid from CUSTOMER_REVIEWS where mid=$MID /* $USERNAME */ and id = ".int($RID);
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my ($pid) = $sth->fetchrow();
		$sth->finish();


		my $pstmt = "select count(1), pid from CUSTOMER_REVIEWS where pid  = ".$dbh->quote($pid)." and MID=$MID";
		# print STDERR $pstmt."\n";
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my ($count, $pid) = $sth->fetchrow();
		$sth->finish();

		## only review for this product
		if ($count <= 1) {
			## remove attrib zoovy:prod_salesrank
			# ZOOVY::saveproduct_attrib($USERNAME,$pid,"zoovy:prod_salesrank",undef);
			my ($P) = PRODUCT->new($USERNAME,$pid);
			if (defined $P) {
				$P->store('zoovy:prod_salesrank');
				$P->save();
				}
			}

		my $pstmt = "delete from CUSTOMER_REVIEWS where MID=$OPTIONS{'MID'} /* $USERNAME */ and ID=".int($RID);
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		}
	else {
		DBINFO::insert($dbh,'CUSTOMER_REVIEWS',\%OPTIONS,key=>['MID','ID'],debug=>1);
		}
	&DBINFO::db_user_close();

	}

##
## pass a CID of -1 for anonymous
##		%info should be LOCATION, SUBJECT, MESSSAGE, RATING, BLOG_URL, IPADDRESS 
##			(via ZTOOLKIT::ip_to_int int_to_ip)
##
sub add_review {
	my ($USERNAME,$PID,$inforef) = @_;

	my %info = %{$inforef};
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $ERROR = '';

	my %kvpairs = ();
	if (defined $info{'ID'}) {
		## updating an existing one.
		}
	else {
		## new entry
		if (not defined $info{'IPADDRESS'}) {
			$kvpairs{'IPADDRESS'} = &ZTOOLKIT::ip_to_int($ENV{'REMOTE_ADDR'});
			}
		}

	$kvpairs{'USERNAME'} = $USERNAME;
	$kvpairs{'MID'} = $MID;
	$kvpairs{'PID'} = $PID;
	if (not defined $info{'ID'}) { $kvpairs{'CREATED_GMT'} = time(); }

	if (defined $info{'USEFUL_YES'}) { $kvpairs{'USEFUL_YES'} = $info{'USEFUL_YES'}; }
	if (defined $info{'USEFUL_NO'}) { $kvpairs{'USEFUL_NO'} = $info{'USEFUL_NO'}; }

	if (not defined $info{'ID'}) { $kvpairs{'RATING'} = -1; }
	if (defined $info{'RATING'}) { $kvpairs{'RATING'} = int($info{'RATING'}); }
	
	if (defined $info{'CUSTOMER_NAME'}) { $kvpairs{'CUSTOMER_NAME'} = $info{'CUSTOMER_NAME'}; }
	elsif (not defined $info{'ID'}) { $info{'CUSTOMER_NAME'} = 'Anonymous'; }

	if (defined $info{'LOCATION'}) { $kvpairs{'LOCATION'} = $info{'LOCATION'}; }
	elsif (not defined $info{'LOCATION'}) { $info{'LOCATION'} = ''; }

	if ($info{'CUSTOMER'} ne '') {
		$kvpairs{'CUSTOMER'} = $info{'CUSTOMER'};
		$kvpairs{'CID'} = &CUSTOMER::resolve_customer_id($USERNAME,0,$info{'CUSTOMER'});
		}
	else {
		$kvpairs{'CUSTOMER'} = '';
		$kvpairs{'CID'} = -1;
		}
	$kvpairs{'SUBJECT'} = (defined $info{'SUBJECT'})?$info{'SUBJECT'}:'';
	$kvpairs{'MESSAGE'} = (defined $info{'MESSAGE'})?$info{'MESSAGE'}:'';
	$kvpairs{'BLOG_URL'} = (defined $info{'BLOG_URL'})?$info{'BLOG_URL'}:'';
	$kvpairs{'ID'} = (defined $info{'ID'})?int($info{'ID'}):0;	# 0 means to insert a new record.

	if ($info{'APPROVED_GMT'}) { $kvpairs{'APPROVED_GMT'} = $^T; }

	#use Data::Dumper;
	#print STDERR Dumper(\%kvpairs);

	&DBINFO::insert($dbh,'CUSTOMER_REVIEWS',\%kvpairs,debug=>1,key=>['ID']);
	&DBINFO::db_user_close();

	return($ERROR);
	}


sub fetch_product_review_summary {
	my ($USERNAME,$PID) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtPID = $dbh->quote($PID);

	my $pstmt = "select count(*),sum(RATING) from CUSTOMER_REVIEWS where MID=$MID /* $USERNAME */ and PID=$qtPID and APPROVED_GMT>0 order by CREATED_GMT desc limit 0,100";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($count,$rating) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();
	return($count,$rating);
	}

##
##
##
sub fetch_product_reviews {
	my ($USERNAME,$PID,$RID) = @_;
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtPID = $dbh->quote($PID);

	my $pstmt = "select ID,CID,CUSTOMER_NAME,LOCATION,PID,CREATED_GMT,SUBJECT,MESSAGE,USEFUL_YES,USEFUL_NO,RATING,BLOG_URL,APPROVED_GMT from CUSTOMER_REVIEWS where MID=$MID /* $USERNAME */ ";
	if ($PID ne '') { $pstmt .= " and PID=$qtPID "; }
	if ($RID > 0) { $pstmt .= " and ID=".int($RID); }
	elsif ($RID == -1) { $pstmt .= " and APPROVED_GMT=0 "; }
	else { $pstmt .= " and APPROVED_GMT>0 "; }
	
	$pstmt .= " order by CREATED_GMT desc limit 0,100";
	# print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my @RESULT = ();
	while (my $hashref = $sth->fetchrow_hashref() ) {
		if ($hashref->{'CUSTOMER_NAME'} eq '') { $hashref->{'CUSTOMER_NAME'} = 'Anonymous'; }
		$hashref->{'RATINGDECIMAL'} = sprintf("%.1f",$hashref->{'RATING'}/2);
		$hashref->{'USEFUL_SUM'} = $hashref->{'USEFUL_YES'}+$hashref->{'USEFUL_NO'};
		push @RESULT, $hashref;
		}
	$sth->finish();

	&DBINFO::db_user_close();

	# print STDERR Dumper(\@RESULT);

	return(\@RESULT);
	}

##
##
##
sub fetch_customer_reviews {
	my ($USERNAME,$CID) = @_;
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::db_user_close();
	}


1;