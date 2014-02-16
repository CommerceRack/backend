package TODO;

use strict;
use warnings;
no warnings 'once';
no warnings 'redefine';


#	my ($t) = TODO->new($USERNAME,writeonly=>1);
#	if (defined $t) {
#		$t->add(title=>"",link=>"product:$PID",class=>"ERROR",detail=>"");
#		}

use Storable;
use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;




##
## intended to be called as:
##		TODO::easylog($USERNAME,title=>,detail=>);
##
## panel=>(look in %TODO::CODES)
## ticket=>
## detail
##
##
sub easylog {
	my ($USERNAME,%options) = @_;

	use Data::Dumper; print STDERR Dumper(\%options);

	if (($options{'code'}) && (not defined $options{'panel'})) {
		$options{'panel'} = 'ERR.'.$options{'code'};
		}

	my $todo = TODO->new($USERNAME,writeonly=>1);
	if (ref($todo) eq 'TODO') {
		$todo->add(%options);
		}
	else {
		warn "could not add to todo!";
		}

	return();
	}


##
## my ($todo) = TODO->new($USERNAME);  # LU is optional
## $todo->delete(dstcode=>"XYZ",pid=>$pid);		## clear any left over errors for this product.
##	$todo->add(
##		class=>"INFO|WARN|MSG|ERROR|SETUP|TODO",		## SETUP = setup tasks, TODO=user created.
##		title=>"100 character short message",
##		detail=>"long description",
##		errcode=>"AMZ#1234,EBAY#1234,",		## see %TODO::CODES below
##		dstcode=>"GOO", ## check SYNDICATION.pm for dstcodes
##		link=>"order:####-##-###|product:ABC|ticket:1234", 
##			or: ticket=>$ticketid, order=>$oid, pid=>$pid,		## this is preferred because it will set other fields.
##		guid=>$related_private_file_guid|$bj->guid(),
##		priority=>1|2|3		## you don't need to set this unless you want to override 1=high,2=warn,3=error
##		group=>		## another way of referencing errcode.
##		panel=>		## the name of the panel which contains a tutorial video (for SETUP tasks)
##		);
##
sub add {
	my ($self, %info) = @_;

	foreach my $k (keys %info) {
		if ($k ne lc($k)) { 
			warn "TODO is converting key $k to lowercase\n";
			$info{lc($k)} = $info{$k}; 
			}
		}

	use Data::Dumper;
	print STDERR Dumper(\%info);

   my ($udbh) = &DBINFO::db_user_connect($self->username());

	if (defined $info{'priority'}) {
		## priority determines where the message appears.
		$info{'priority'} = int($info{'priority'});
		}
	elsif (defined $info{'class'}) {
		## class is usually INFO|WARN|ERROR
		if ($info{'class'} eq 'INFO') { $info{'priority'} = 3; }
		elsif ($info{'class'} eq 'WARN') { $info{'priority'} = 2; }
		elsif ($info{'class'} eq 'MSG') { $info{'priority'} = 2; }
		elsif ($info{'class'} eq 'ERROR') { $info{'priority'} = 1; }
		else { $info{'priority'} = 0; }
		}
	else {
		$info{'priority'} = 0;
		}
	if (not defined $info{'ticket'}) { $info{'ticket'} = 0; }
	if (not defined $info{'panel'}) { $info{'panel'} = ''; }		# 
	if (not defined $info{'title'}) { $info{'title'} = ''; }		# short (100 byte) description of the error
	if (not defined $info{'detail'}) { $info{'detail'} = ''; }	# long description (65536 characters)
	if (not defined $info{'pid'}) { $info{'pid'} = ''; }			# pid (optional)
	if (not defined $info{'dstcode'}) { $info{'dstcode'} = ''; }# marketplace (see SYNDICATION.pm for codes)
	if (not defined $info{'guid'}) { $info{'guid'} = ''; }		# guid of privatefile (not multiple tasks can share a file)
	if ($info{'ticket'}>0) {
		$self->clearTicket($info{'ticket'});
		}

	if (defined $info{'name'}) {
		## upgrade task to new specs
		$info{'title'} = $info{'name'}; delete $info{'name'};
		}

	if (not defined $info{'created'}) { $info{'created'} = time(); }
	if (not defined $info{'class'}) { $info{'class'} = 'TODO'; }
   if ((defined $info{'ticket'}) && ($info{'ticket'}>0)) {
      $info{'link'} = "ticket:".$info{'ticket'};
      }
  	elsif ((defined $info{'order'}) && ($info{'order'} ne '')) {
      $info{'link'} = "order:".$info{'order'};
      }
  	elsif ((defined $info{'pid'}) && ($info{'pid'} ne '')) {
      $info{'link'} = "product:".$info{'pid'};
      }


	my $assignto = $self->luser();
	if (defined $info{'assignto'}) { $assignto = $info{'assignto'}; }
	elsif (defined $info{'luser'}) { $assignto = $info{'luser'}; }
	
	if (not defined $info{'link'}) { $info{'link'} = ''; }
	if (not defined $info{'group'}) { $info{'group'} = ''; }

	if (defined $info{'errcode'}) {
		$info{'group'} = $info{'errcode'};
		}

	my ($pstmt) = &DBINFO::insert($udbh,'TODO',{
		USERNAME=>$self->username(),
		MID=>$self->mid(),
		LUSER=>sprintf("%s",$assignto),
		PID=>sprintf("%s",$info{'pid'}),
		DSTCODE=>sprintf("%s",$info{'dstcode'}),
		CLASS=>$info{'class'},
		CREATED_GMT=>sprintf("%d",$info{'created'}),
		TITLE=>sprintf("%s",$info{'title'}),
		DETAIL=>sprintf("%s",$info{'detail'}),
      LINK=>sprintf("%s",$info{'link'}),
		TICKET_ID=>sprintf("%d",$info{'ticket'}),
		GROUPCODE=>sprintf("%s",$info{'group'}),
		PRIORITY=>int($info{'priority'}),
		PANEL=>sprintf("%s",$info{'panel'}),
		PRIVATEFILE_GUID=>sprintf("%s",$info{'guid'}),
		},debug=>1+2);

	$udbh->do($pstmt);
	if (not $self->{'writeonly'}) {
		my ($id) = &DBINFO::last_insert_id($udbh);
		$info{'id'} = $id;
	
		if ($id>0) {
			$pstmt = "select * from TODO where MID=".int($self->mid())." and ID=".int($id);
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			my ($todoref) = $sth->fetchrow_hashref();
			$sth->finish();
			push @{$self->{'@TASKS'}}, $todoref;
			}
		}

	&DBINFO::db_user_close();
	}



##
## returns the number of uncompleted items
##
sub items {
	my ($self) = @_;

	my $count = 0;
	foreach my $task (@{$self->{'@TASKS'}}) {
		next if ((defined $task->{'completed'}) && ($task->{'completed'}>0));
		$count++;		
		}
	return($count);	
	}


sub username { return($_[0]->{'USERNAME'}); }
sub luser { return( (defined $_[0]->{'LUSERNAME'})?$_[0]->{'LUSERNAME'}:''); }
sub mid { return(int($_[0]->{'MID'})); }

##
##   $GTOOLS::TAG{'<!-- MYTODO -->'} = $t->mytodo_box([
##      { done=>0, txt=>"you need to give JT a helicopter.", help=>"" },
##      { done=>1, txt=>"kick jt in the nuts.", help=>"" },
##      ]);
##
sub mytodo_box {
	my ($self,$id,$tasks) = @_;

	my $html = '';
	my $alldone = 1;
	foreach my $task (@{$tasks}) {
		my ($class) = ($task->{'done'})?'done':'undone'; 
		if (not $task->{'done'}) { $alldone = 0; }
		$html .= "<div class=\"$class\">";
		$html .= $task->{'txt'};
		if ($task->{'help'} ne '') {
			$html .= "  [ <a href=\"$task->{'help'}\">help</a> ]";
			}
		$html .= "</div>";
		}

	if (not $alldone) {
		## NOT DONE
		$html = qq~
<div style="background-image:url(/biz/todo/images/items_to_do_banner-797x69.jpg); background-repeat:no-repeat; width:797px; height:69px">
<table width="797" border="0" cellpadding="0" cellspacing="0">
  <tr>
	<td width="250">&nbsp;</td>
  	<td width="319"><div>$html</div></td>
    <td width="225" valign="top">
   	 <a target="_top" href="/biz/index.cgi?focus=$id" id="show_me_button"></a>    </td>
  </tr>
</table></div>
~;
		}
	else {
		## DONE
		$html = qq~
<div style="background-image:url(/biz/todo/images/items_done_banner-797x69.jpg); background-repeat:no-repeat; width:797px; height:69px">
<table width="797" border="0" cellpadding="0" cellspacing="0">
  <tr>
	<td width="250">&nbsp;</td>
  	<td width="319"><table><tr><td>$html</td></tr></table></td>
    <td width="225" valign="top">
   	 <a target="_top" href="/biz/index.cgi?focusfrom=$id" id="to_do_button"></a>    </td>
  </tr>
</table></div>
~;
		}

	return($html);
	}


##
##
##
##

sub clearTicket {
	my ($self,$ticket) = @_;

	if ($ticket>0) {
		my $dbh = &DBINFO::db_user_connect($self->username());
		my $pstmt = "delete from TODO where MID=".int($self->mid())." and TICKET_ID=".int($ticket);
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		&DBINFO::db_user_close();
		}

	}

##
## overview of $listref
##		{
##		'counter'=>'#',
##		'sort'=>'sort key',
##		'@TASKS'=>[
##				{ name=>'Task', assignedby=>'', link=>'', code=>'ABC', grp=>'SETUP' }
##				{ name=>'Task', assignedby=>'', link=>'', code=>'ABC', grp=>'SETUP' }
##				]
##



sub count {
	my ($self) = @_;
	return(scalar( @{$self->{'@TASKS'}} )); 
	}

##
##
##
##
sub verify {
	my ($self) = @_;

	my @verifiedtasks = ();			# this will be the new $self->{'@TASKS'} when we're done.
	my %TICKETS_CHECK = ();		# a list of tickets we ought to check
	my $changed = 0;

	my $webdbref = undef;

	foreach my $task (@{$self->{'@TASKS'}}) {
		next if ((defined $task->{'completed'}) && ($task->{'completed'}>0));
		my $completed = 0;
	
		## matches setup tasks
		if (not defined $task->{'code'}) { $task->{'code'} = ''; }

		if ($task->{'LINK'} =~ /SETUP:/) {
			if (not defined $webdbref) { $webdbref = &ZWEBSITE::fetch_website_dbref($self->username(),0); }
			
			#if ($task->{'LINK'} eq 'SETUP:HASPHONE') {
			#	## checks company info
			#	if ('' ne &ZOOVY::fetchmerchant_attrib($self->username(),'zoovy:phone')) { $completed++; }
			#	elsif ('' ne &ZOOVY::fetchmerchant_attrib($self->username(),'zoovy:support_phone')) { $completed++; }
			#	elsif ('' ne &ZOOVY::fetchmerchant_attrib($self->username(),'zoovy:city')) { $completed++; }
			#	}
			#elsif ($task->{'LINK'} eq 'SETUP:HASTHEME') {
			#	## selected a website theme
			#	require ZWEBSITE;
			#	if (uc($webdbref->{'sitewrapper'}) eq 'DEFAULT') {  }# this set by setup
			#	elsif ($webdbref->{'sitewrapper'} ne '') { $completed++; }
			#	}
			if ($task->{'LINK'} eq 'SETUP:HASNAVCAT') {
				## selected navigation categories
				require NAVCAT;
				my ($NC) = NAVCAT->new($self->username(),PRT=>0);
				if (not defined $NC) {}
				elsif (scalar($NC->paths())>1) { $completed++; }
				undef $NC;
				}
			elsif ($task->{'LINK'} eq 'SETUP:HASPRODUCT') {
				if (scalar(&ZOOVY::fetchproduct_list_by_merchant($self->username()))>0) { $completed++; }
				}
			elsif ($task->{'LINK'} eq 'SETUP:HASPAYMENT') {
				require ZWEBSITE;
				if ($webdbref->{'payable_to'} ne '') { $completed++; }
				if ($webdbref->{'pay_cash'} ne '') { $completed++; }
				if ($webdbref->{'cc_type_visa'} ne '') { $completed++; }
				}
			elsif ($task->{'LINK'} eq 'SETUP:HASSHIPPING') {
				require ZWEBSITE;
				if ($webdbref->{'ship_int_risk'} ne '') { $completed++; }
				}
			elsif ($task->{'LINK'} eq 'SETUP:HASTAX') {
				require ZWEBSITE;
				if ($webdbref->{'tax_rules'} ne '') { $completed++; }
				}
			#elsif ($task->{'LINK'} eq 'SETUP:EBAY') {
			#	require ZWEBSITE;
			#	if ($webdbref->{'ebay'} ne '') { $completed++; }
			#	}
			elsif ($task->{'LINK'} eq 'SETUP:SYNDICATION') {
				my ($dbh) = &DBINFO::db_user_connect($self->username());
				my $pstmt = "select count(*) from SYNDICATION where MID=".int($self->mid())." /* ".$self->username()." */";
				my $sth = $dbh->prepare($pstmt);
				$sth->execute();
				my ($count) = $sth->fetchrow();
				$sth->finish();
				&DBINFO::db_user_close();
				require ZWEBSITE;
				
				if ($count>0) { $completed++; }
				}
			#elsif ($task->{'LINK'} eq 'SETUP:COMPANYLOGO') {
			#	if ('' ne &ZOOVY::fetchmerchant_attrib($self->username(),'zoovy:company_logo')) { $completed++; }
			#	}
			}
		## end of setup tasks


		## recommended download of clients
		if ($task->{'LINK'} =~ /DOWNLOAD:/) {
			if ($task->{'LINK'} eq 'DOWNLOAD:ZOM') {
				my $dbh = &DBINFO::db_user_connect($self->username());
				my $pstmt = "select count(*) from SYNC_LOG where USERNAME=".$dbh->quote($self->username());
				my $sth = $dbh->prepare($pstmt);
				$sth->execute();
				($completed) = $sth->fetchrow();
				$sth->finish();
				&DBINFO::db_user_close();
				}
			}
		## end client downloads


		if ($task->{'LINK'} eq 'SUPPORT:TICKET') {
			my $TICKET = $task->{'ticket'};
			## if $TICKET already already exists in TICKETS_CHECK it's a dup and can be completed!
			if (not defined $TICKETS_CHECK{$TICKET}) { 
				$TICKETS_CHECK{$TICKET} = $task; 
				} 
			}
		elsif ($completed) {
			## hurrah!
			$self->complete($task->{'id'}); $changed++;
			}
		else {
			## NOTE: tickets are NOT added to verified tasks
			push @verifiedtasks, $task;
			}
		}

	## now handle the batch of tickets.
	if (scalar(keys %TICKETS_CHECK)>0) {

#		require SUPPORT;
#		my ($sdbh) = SUPPORT::db_support_connect();
#		push @verifiedtasks, $task;
#		&SUPPORT::db_support_close();

#		require LWP::UserAgent;
#		require HTTP::Request::Common;
#		require LWP::Simple;
#		require HTTP::Request;
#
#	
#		my $url = "http://support.zoovy.com/xmlstatus.cgi?TICKETS=".join(',',keys %TICKETS_CHECK);
#		my $agent = new LWP::UserAgent;
#		$agent->agent('Groovy-Zoovy/2.0');
#		my $result = $agent->get($url);
#				
#		if ($result->content() =~ /<tickets>(.*?)<\/tickets>/s) {
#			my $tref = &ZTOOLKIT::xmlish_list_to_arrayref($1,tag_attrib=>'TICKET');
#			foreach my $tkt (@{$tref}) {
#				my $task = $TICKETS_CHECK{$tkt->{'ID'}};
#				next if (not defined $task);
#				
#				if ($tkt->{'DISPOSITION'} ne 'WAITING') {
#					$self->complete($task->{'id'}); $changed++;
#					}
#				else {
#					$task->{'name'} = 'Ticket '.$tkt->{'ID'}.': '.$tkt->{'SUBJECT'}.' -- please respond.';
#					push @verifiedtasks, $task;	
#					}
#				}
#			$tref = undef;
#			}
#
		}

	$self->{'@TASKS'} = \@verifiedtasks;
	if ($changed) { $self->save(); }

	return();
	}


#sub as_xml {
#	my ($self) = @_;
#
#	require ZTOOLKIT;
#	my $XML = '<ToDo>';
#	$XML .= '<User>'.&ZOOVY::incode($self->username()).'</User>';
#	$XML .= '<Sort>'.&ZOOVY::incode($self->{'sort'}).'</Sort>';
#	$XML .= '<Tasks>';
#	foreach my $t (@{$self->list()}) {
#		$t->{'PANEL'} = 'setup_channels.jpg';
#		foreach my $k (keys %{$t}) {
#			$t->{$k} =~ s/^[\n\r\t]+//gs;		# strip beginning newlines for brandon
#			$t->{$k} =~ s/[\t]+//gs;
#			}
#		$XML .= '<task>';
#		$XML .= &ZTOOLKIT::hashref_to_xmlish($t,'encoder'=>'latin1','newlines'=>0);
#		$XML .= '</task>';
#		}	
#	$XML .= '</Tasks></ToDo>';
#	return($XML);
#	}



##
## loads a todo list
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	if (not defined $USERNAME) { return undef; }
	if ($USERNAME eq '') { return undef; }

	my $LUSERNAME = $options{'LUSER'};
	if (index($USERNAME,'*')>0) { ($USERNAME,$LUSERNAME) = split(/\*/,$USERNAME); }
	if ($options{'app'}) {
		$LUSERNAME = uc("*".$options{'app'});
		}

	my $self = {};
	bless $self, 'TODO';

	$self->{'USERNAME'} = $USERNAME;
	$self->{'LUSERNAME'} = $LUSERNAME;
	$self->{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$self->{'counter'} = 1;
	$self->{'@TASKS'} = [];
	$self->{'sort'} = 'id';
	if (not defined $options{'writeonly'}) { $options{'writeonly'} = 0; }
	$self->{'writeonly'} = int($options{'writeonly'});

	if (not $self->{'writeonly'}) {
		my $dbh = &DBINFO::db_user_connect($self->username());
		my $qtLUSER = $dbh->quote($LUSERNAME);

		my $pstmt = "select * from TODO where MID=$self->{'MID'} /* $self->{'USERNAME'} */";
		#  and LUSER in ('',$qtLUSER)";
		print STDERR $pstmt."\n";
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		while ( my $todoref = $sth->fetchrow_hashref() ) {
			push @{$self->{'@TASKS'}}, $todoref;
			}
		$sth->finish();
		&DBINFO::db_user_close();	
		}

	return($self);
	}


sub list {
	my ($self) = @_;
	return($self->{'@TASKS'});
	}


sub update {
	my ($self, $taskid, %attribs) = @_;

#| PID              | varchar(20)                                   | NO   |     | NULL    |                |
#| DSTCODE          | varchar(3)                                    | NO   |     | NULL    |                |
#| CLASS            | enum('INFO','SETUP','TODO','WARN','ERROR','') | NO   |     | NULL    |                |
#| PRIORITY         | tinyint(3) unsigned                           | YES  |     | 0       |                |
#| CREATED_GMT      | int(10) unsigned                              | NO   |     | 0       |                |
#| DUE_GMT          | int(10) unsigned                              | YES  |     | 0       |                |
#| EXPIRES_GMT      | int(10) unsigned                              | NO   |     | 0       |                |
#| COMPLETED_GMT    | int(10) unsigned                              | NO   |     | 0       |                |
#| TITLE            | varchar(100)                                  | NO   |     | NULL    |                |
#| DETAIL           | text                                          | NO   |     | NULL    |                |
#| LINK             | varchar(100)                                  | NO   |     | NULL    |                |
#| TICKET_ID        | int(10) unsigned                              | NO   |     | 0       |                |
#| GROUPCODE        | varchar(25)                                   | NO   |     | NULL    |                |
#| PANEL            | varchar(50)                                   | YES  |     | NULL    |                |
#| PRIVATEFILE_GUID | varchar(36)                                   | NO   |     | NULL    |                |
	my $MID = $self->mid();
	my $updated = 0;
	foreach my $task (@{$self->{'@TASKS'}}) {
		if ($task->{'ID'} == $taskid) {
			my %vars = ();
			foreach my $k ('title','priority','due_gmt','detail','luser') {
				if (defined $attribs{$k}) {
					$vars{uc($k)} = $attribs{$k};
					$task->{uc($k)} = $attribs{$k};
					}
				}
			if (scalar(keys %vars)>0) {
				$updated++;
				my ($udbh) = &DBINFO::db_user_connect($self->username());
				my $pstmt = &DBINFO::insert($udbh,'TODO',\%vars,sql=>1,'verb'=>'update','key'=>{'MID'=>$MID,'ID'=>int($taskid)});
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				&DBINFO::db_user_close();
				}
			}
		}
	$self->save();
	return($updated);
	}


##
## saves a todo list
##
sub save {
	my ($self) = @_;

	warn "TODO save called";
#	if ($self->{'USERNAME'} eq '') { return(-1); }
#	
#	my $path = &ZOOVY::resolve_userpath($self->{'USERNAME'});		
#	store $self, "$path/TODO.bin";
#	chmod 0777, "$path/TODO.bin";

	return(0);
	}

##
##
## can pass either a task id
##	or:
##		class=>'',panel=>''
##		class=>'',group=>''
##		dstcode=>'', pid=>''
##
sub delete {
	my ($self,$id,%options) = @_;

	## legacy compatibility mode:
	if ($id>0) { $options{'id'} = int($id); }

	my $dbh = &DBINFO::db_user_connect($self->username());

	my $matchsub = undef;


	my ($MID) = $self->mid();
	if ((defined $options{'id'}) && ($options{'id'}>0)) {
		my $pstmt = "delete from TODO where MID=$MID and ID=".int($id);
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$matchsub = sub { 
			my ($task,%options) = @_;
			return($task->{'ID'} eq $id);
			};
		}
	elsif ((defined $options{'pid'}) && (defined $options{'dstcode'})) {
		my $pstmt = "delete from TODO where MID=$MID and PID=".$dbh->quote($options{'pid'})." and DSTCODE=".$dbh->quote($options{'dstcode'});
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$matchsub = sub { 
			my ($task,%options) = @_;
			# print "CLASS: $task->{'CLASS'} eq $options{'class'} && $task->{'PANEL'} eq $options{'panel'}\n";
			return(($task->{'DSTCODE'} eq $options{'dstcode'}) && ($task->{'PID'} eq $options{'pid'})); 
			};
		}
	elsif ((defined $options{'class'}) && (defined $options{'panel'})) {
		## we passed id of zero, and class + panel
		my $pstmt = "delete from TODO where MID=$MID and CLASS=".$dbh->quote($options{'class'})." and PANEL=".$dbh->quote($options{'panel'});
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$matchsub = sub { 
			my ($task,%options) = @_;
			# print "CLASS: $task->{'CLASS'} eq $options{'class'} && $task->{'PANEL'} eq $options{'panel'}\n";
			return(($task->{'CLASS'} eq $options{'class'}) && ($task->{'PANEL'} eq $options{'panel'})); 
			};
		}
	elsif ((defined $options{'class'}) && (defined $options{'group'})) {
		## we passed id of zero, and class + panel
		my $pstmt = "delete from TODO where MID=$MID and CLASS=".$dbh->quote($options{'class'})." and GROUPCODE=".$dbh->quote($options{'group'});
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$matchsub = sub { 
			my ($task,%options) = @_;
			return(($task->{'CLASS'} eq $options{'class'}) && ($task->{'GROUPCODE'} eq $options{'group'})); 
			};
		}
	elsif (defined $options{'class'}) {
		## we passed id of zero, and class + panel
		my $pstmt = "delete from TODO where MID=$MID and CLASS=".$dbh->quote($options{'class'});
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$matchsub = sub { 
			my ($task,%options) = @_;
			return($task->{'CLASS'} eq $options{'class'}); 
			};
		}
	&DBINFO::db_user_close();

	if (defined $matchsub) {
		# use Data::Dumper; print Dumper($matchsub);
		my @ar = ();
		foreach my $task (@{$self->{'@TASKS'}}) {
			next if (not defined $task->{'ID'});
			my ($matches) = $matchsub->($task,%options);
			# print "MATCHES: $matches\n";
			next if ($matches);
			# next if (($task->{'CLASS'} eq $options{'class'}) && ($task->{'PANEL'} eq $options{'panel'}));
			push @ar, $task;
			}
		$self->{'@TASKS'} = \@ar;
		}

	return($self);	
	}







##
## pass in a task, OR an arrayref of tasks that need to be assigned
##
sub assignto {
	my ($self,$tasksar,$luser) = @_;

	if (ref($tasksar) eq '') {
		## we got a scalar, not an array
		$tasksar = [ $tasksar ];
		}

	my %TASKIDS = ();
	foreach my $tid (@{$tasksar}) { 
		## note: we MUST int them here so we don't screw up database in TASKSSQL
		$TASKIDS{int($tid)}++; 
		}
	my $TASKSSQL = join(',',keys %TASKIDS);

	my $dbh = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my $pstmt = "update TODO set LUSER=".$dbh->quote($luser)." where MID=$MID and ID in ($TASKSSQL)";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	
	my @ar = ();
	foreach my $task (@{$self->{'@TASKS'}}) {
		my $tid = $task->{'ID'};
		next if (not defined $TASKIDS{$tid});
		$task->{'LUSER'} = $luser;
		}
	return($self);
	}

##
##
## 
sub complete {
	my ($self,$id) = @_;

	if (not defined $id) {
		warn "TODO called complete with id set to undef (wtf?)";
		return($self);
		}

	my $dbh = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my $pstmt = "update TODO set COMPLETED_GMT=".time()." where MID=$MID and ID=".int($id);
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	
	if (not defined $id) { $id = 0; }

	my @ar = ();
	foreach my $task (@{$self->{'@TASKS'}}) {
		next if ($task->{'ID'}==0);
		next if (not defined $task->{'ID'});		
		if ($task->{'ID'} == $id) { $task->{'COMPLETED_GMT'} = time(); }
		}
	return($self);	
	}


##
## returns a hashref keyed by 'USER' 
##		
##
#sub list_users {
#	my ($USERNAME) = @_;
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
#	my %ar = ();
#	$ar{'ADMIN'} = { 'LUSER'=>'ADMIN', FULLNAME=>'Administrator' };
#
#	my $dbh = &DBINFO::db_zoovy_connect();
#	my $pstmt = "select LUSER,FULLNAME from ZUSER_LOGIN where MID=$MID";
#	my $sth = $dbh->prepare($pstmt);
#	$sth->execute();
#	while ( my ($luser,$fullname) = $sth->fetchrow() ) {
#		$ar{$luser} = { 'LUSER'=>$luser, FULLNAME=>$fullname };		
#		}
#
#	&DBINFO::db_zoovy_close();
#	return(\%ar);
#	}
#sub set_sort {
#	my ($self, $sort) = @_;
#	$sort = lc($sort);
#
#	## the - means to do a reverse sort
#	if ($self->{'sort'} eq $sort) { 
#		$self->{'sort'} = '-'.$sort; 
#		} 
#	else { 
#		$self->{'sort'} = $sort; 
#		}
#	}

##
##
#sub list {
#	my ($self, %options) = @_;
#
#
#	return(\@ar);
#	}



1;