package SYNDICATION::EVENT;

use strict;


#mysql> desc SYNDICATION_QUEUED_EVENTS;
#+---------------+------------------+------+-----+---------+----------------+
#| Field         | Type             | Null | Key | Default | Extra          |
#+---------------+------------------+------+-----+---------+----------------+
#| ID            | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
#| USERNAME      | varchar(20)      | NO   |     | NULL    |                |
#| MID           | int(10) unsigned | NO   | MUL | 0       |                |
#| PRODUCT       | varchar(20)      | NO   |     | NULL    |                |
#| SKU           | varchar(35)      | NO   |     | NULL    |                |
#| CREATED_GMT   | int(10) unsigned | NO   |     | 0       |                |
#| PROCESSED_GMT | int(10) unsigned | NO   |     | 0       |                |
#| DST           | varchar(3)       | NO   |     | NULL    |                |
#| VERB          | varchar(10)      | NO   |     | NULL    |                |
#| ORIGIN_EVENT  | int(10) unsigned | NO   |     | 0       |                |
#+---------------+------------------+------+-----+---------+----------------+
#10 rows in set (0.01 sec)



##
## adds a new verb to the syndication events queue
##
sub add {
	my ($USERNAME,$PRODUCT,$DST,$VERB,%options) = @_;

	## default SKU to PRODUCT
	my ($SKU) = $options{'SKU'};
	if ($SKU eq '') { $SKU = $PRODUCT; }

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my %vars = ();
	$vars{'USERNAME'} = $USERNAME;
	$vars{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$vars{'PRODUCT'} = $PRODUCT;
	$vars{'SKU'} = $SKU;
	$vars{'DST'} = $DST;
	$vars{'VERB'} = $VERB;
	$vars{'CREATED_GMT'} = time();
	if ($options{'CREATE_LATER'}) {
		$vars{'CREATED_GMT'} += int($options{'CREATE_LATER'});	
		$vars{'CREATED_GMT'} -= ($vars{'CREATED_GMT'} % 600);	## round to the nearest 10 minutes for pretty logs+debug
		}

	my $pstmt = &DBINFO::insert($udbh,'SYNDICATION_QUEUED_EVENTS',\%vars,sql=>1,'verb'=>'insert');
	$udbh->do($pstmt);

	$pstmt = "select last_insert_id()";
	my ($ID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return($ID);
	}


##
##
##
sub list {
	my ($USERNAME,%filters) = @_;

	}


1;