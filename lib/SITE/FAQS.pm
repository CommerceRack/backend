package SITE::FAQS;
use strict;
use Data::Dumper;

#mysql> desc FAQ_ANSWERS;
#+---------------+--------------+------+-----+---------+----------------+
#| Field         | Type         | Null | Key | Default | Extra          |
#+---------------+--------------+------+-----+---------+----------------+
#| ID            | int(11)      |      | PRI | NULL    | auto_increment |
#| MID           | int(11)      |      | MUL | 0       |                |
#| USERNAME      | varchar(20)  |      |     | NULL    |                |
#| TOPIC_ID      | int(11)      |      |     | 0       |                |
#| KEYWORDS      | varchar(128) |      |     | NULL    |                |
#| QUESTION      | varchar(80)  |      |     | NULL    |                |
#| ANSWER        | tinytext     |      |     | NULL    |                |
#| LIMIT_PROFILE | varchar(8)   |      |     | NULL    |                |
#+---------------+--------------+------+-----+---------+----------------+
#8 rows in set (0.02 sec)

#mysql> desc FAQ_TOPICS;
#+----------+-------------+------+-----+---------+----------------+
#| Field    | Type        | Null | Key | Default | Extra          |
#+----------+-------------+------+-----+---------+----------------+
#| ID       | int(11)     |      | PRI | NULL    | auto_increment |
#| MID      | int(11)     |      | MUL | 0       |                |
#| USERNAME | varchar(20) |      |     | NULL    |                |
#| TITLE    | varchar(30) |      |     | NULL    |                |
#+----------+-------------+------+-----+---------+----------------+
#4 rows in set (0.01 sec)

sub username { return($_[0]->{'_USERNAME'}); }


sub new {
	my ($class,$USERNAME,$PRT) = @_;

	my $self = {};
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MID'} = &ZOOVY::resolve_mid($USERNAME);
	$self->{'_PRT'} = int($PRT);
	
	bless $self, 'SITE::FAQS';

	return($self);
	}


##
##
sub restrict {
	my ($self, %options) = @_;

	if ($options{'KEYWORDS'} ne '') {
		my (@words) = split(/[^A-Z0-9]+/s,uc($options{'KEYWORDS'}));

		## create a valid list of topics.
		my $dbh = &DBINFO::db_user_connect($self->username());		
		my $pstmt = "select ID,TOPIC_ID,concat(QUESTION,' ',ANSWER,' ',KEYWORDS) as txt from FAQ_ANSWERS where PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'} */";
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my %topics = ();
		my %faqs = ();
		while ( my ($faq_id, $topic_id, $txt) = $sth->fetchrow() ) {
			$txt = uc($txt);
			print STDERR "$faq_id, $topic_id, $txt\n";
			foreach my $sword (split(/[^A-Z0-9]+/s,$txt)) {
				foreach my $word (@words) {
					next if ($word eq '');
					if ($word eq $sword) { $topics{$topic_id}++; $faqs{$faq_id}++; }
					}
				}
			}
		&DBINFO::db_user_close();
		
		$self->{'_LIMIT_TOPICS'} = []; 
		foreach my $topic_id (keys %topics) {
			push @{$self->{'_LIMIT_TOPICS'}}, $topic_id;
			}
		$self->{'_LIMIT_FAQS'} = []; 
		foreach my $faq_id (keys %faqs) {
			push @{$self->{'_LIMIT_FAQS'}}, $faq_id;
			}
		}


	if ($options{'TOPIC_ID'}>0) {
		## restricts us to a specific topic.
		if (not defined $self->{'_LIMIT_TOPIC'}) { $self->{'_LIMIT_TOPICS'} = []; }
		$self->{'_LIMIT_TOPICS'} = [$options{'TOPIC_ID'}];
		}
	

	}


##
##
##
sub add_topic {
	my ($self, $TITLE, $PRIORITY, %params) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $v = {
		ID=>0, MID=>$self->{'_MID'}, PRT=>$self->{'_PRT'}, USERNAME=>$self->{'_USERNAME'}, PRIORITY=>int($PRIORITY), TITLE=>$TITLE
		};

	if (defined $params{'ID'}) {
		$v->{'ID'} = int($params{'ID'});
		&DBINFO::insert($dbh,'FAQ_TOPICS', $v, update=>2, key=>['MID','PRT','ID']);
		}
	else {
		&DBINFO::insert($dbh,'FAQ_TOPICS', $v, update=>0, key=>['MID','PRT','ID']);
		}



	&DBINFO::db_user_close();
	};

##
##
sub remove_topic {
	my ($self ,$TOPICID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "delete from FAQ_TOPICS where ID=".int($TOPICID)." and PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; */";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	$pstmt = "delete from FAQ_ANSWERS where TOPIC_ID=".int($TOPICID)." and PRT=$self->{'_PRT'}  and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; */";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	&DBINFO::db_user_close();
	}


##
## 
sub edit_topic {
	my ($self, $TOPICID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "update FAQ_ANSWERS set ANSWER=' where ID=".int($TOPICID)." and PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; set ID=".int($TOPICID)."*/";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	&DBINFO::db_user_close();
	}	


##
##
sub get_topic {
	my ($self, $TOPICID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());
	
	my $pstmt = "select * from FAQ_TOPICS where ID=".int($TOPICID)." and PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'} */";
	my $result = $dbh->selectrow_hashref($pstmt);

	#$result = $pstmt;	

	&DBINFO::db_user_close();
	return($result);
	}

#
## returns an array of topics
##		each element is a hashref with TITLE=> and ID=>
sub list_topics {
	my ($self) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	# use Data::Dumper; print STDERR Dumper($self);

	my $pstmt = "select ID,PRIORITY,TITLE from FAQ_TOPICS where MID=$self->{'_MID'} and PRT=$self->{'_PRT'}  /* $self->{'_USERNAME'}; */";
	if ($self->{'_LIMIT_TOPICS'}) {
		$pstmt .= " and ID in (".join(',',@{$self->{'_LIMIT_TOPICS'}}).") ";
		}
	$pstmt .= " order by PRIORITY";
	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my @result = ();
	while (my $hashref = $sth->fetchrow_hashref()) {
		push @result, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	print STDERR Dumper(\@result);

	return(\@result);
	}

##
## FAQID should be zero for new faqs
##
sub add_faq {
	my ($self,$FAQID,$TOPICID,$Q,$A,$KEYS,$PRIORITY) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	&DBINFO::insert($dbh,'FAQ_ANSWERS', {
		ID=>int($FAQID), MID=>$self->{'_MID'}, PRT=>$self->{'_PRT'}, USERNAME=>$self->{'_USERNAME'}, TOPIC_ID=>$TOPICID, KEYWORDS=>$KEYS, QUESTION=>$Q, ANSWER=>$A, PRIORITY=>$PRIORITY
		},key=>['ID','MID','PRT']);
	&DBINFO::db_user_close();
	}

##
##
##
sub remove_faq {
	my ($self,$FAQID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "delete from FAQ_ANSWERS where ID=".int($FAQID)." and PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; */";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
##
##
sub list_faqs {
	my ($self,$TOPICID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "select ID,QUESTION,ANSWER,KEYWORDS,PRIORITY,TOPIC_ID from FAQ_ANSWERS where PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; */";
	if (defined $TOPICID) { 
		$pstmt .= " and TOPIC_ID=".int($TOPICID);
		}
	if (defined $self->{'_LIMIT_FAQS'}) {
		$pstmt .= " and ID in (".join(',',@{$self->{'_LIMIT_FAQS'}}).") ";
		}
	if (defined $self->{'_LIMIT_TOPICS'}) {
		$pstmt .= " and TOPIC_ID in (".join(',',@{$self->{'_LIMIT_TOPICS'}}).") ";
		}
	$pstmt .= " order by TOPIC_ID,PRIORITY",

	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my @result = ();
	while (my $hashref = $sth->fetchrow_hashref()) {
		push @result, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@result);
	}


sub get_faq {
	my ($self,$FAQID) = @_;

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "select ID,PRIORITY,TOPIC_ID,QUESTION,ANSWER,KEYWORDS from FAQ_ANSWERS where ID=".int($FAQID)." and PRT=$self->{'_PRT'} and MID=$self->{'_MID'} /* $self->{'_USERNAME'}; */";
	my $ref = $dbh->selectrow_hashref($pstmt);
	&DBINFO::db_user_close();
	return($ref);
	}

1;