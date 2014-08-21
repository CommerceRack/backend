package BATCHJOB;

use strict;

##
##  /backend/lib/batch.pl brian report 1
##

use lib "/backend/lib";
require DBINFO;
require LISTING::MSGS;
require ZTOOLKIT;
require YAML::Syck;


#
# JOB_TYPES
#
%BATCHJOB::JOBTYPES = (
	''=>'Job Type Not Specified',
	'PPT'=>"Product Power Tool"
	);

sub domain { my ($self) = @_; return($self->get('.DOMAIN'));  }

sub find_jobs {
	my ($USERNAME, %options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my @JOBS = ();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select ID,TITLE,unix_timestamp(CREATED_TS) as CREATED_GMT,LUSERNAME,STATUS from BATCH_JOBS where MID=$MID /* $USERNAME */ ";
	if ($options{'JOB_TYPE'}) {
		$pstmt .= " and JOB_TYPE=".$udbh->quote($options{'JOB_TYPE'});
		}
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @JOBS, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@JOBS);
	}


sub logmsgs {
	my ($self, $AREA, $MSGS) = @_;
	require LUSER;
	my ($MODULE,$VERB) = $self->execverb();
	my $TYPE = sprintf("JOB#%d:%s.%s",$self->id(),$MODULE,$VERB);
	LUSER::log( { LUSER=>$self->lusername(), USERNAME=>$self->username() }, $AREA, $MSGS, $TYPE);	
	}

##
## resolves a batch job id, from a guid.
##
sub resolve_guid {
	my ($USERNAME,$GUID) = @_;

	if ($GUID eq '') { return(0); }

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select ID from BATCH_JOBS where MID=$MID /* $USERNAME */ and GUID=".$udbh->quote($GUID);
	print STDERR $pstmt."\n";
	my ($JOBID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return(int($JOBID));
	}

##
## utility function, returns a guid.
##
sub make_guid {
	require Data::GUID;
	my $guid = Data::GUID->new();
	my $string = $guid->as_string; # or "$guid"
	($string) = substr($string,0,32);
	return($string);
	}


##
## progress 
##
sub progress {
	my ($self, $records_done, $records_total, $msg, $notes) = @_;

	# print STDERR "$records_done/$records_total: $msg\n";
	if (defined $self) {
		my %OPTIONS = (
			ESTDONE_TS=>&ZTOOLKIT::timestamp(time()),
			RECORDS_DONE=>$records_done,
			RECORDS_TOTAL=>$records_total,
			STATUS=>'RUNNING',
			STATUS_MSG=>$msg,
			);
		## if (defined $notes) { $OPTIONS{'NOTES'} = $notes; }
		$self->update(%OPTIONS);
		}
	}



##
##
sub new {
	my ($class, $USERNAME, $ID, %options) = @_;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $self = {};
	if ($ID>0) {
		## even if this is a new entry, we still load it from the db.
		my $pstmt = "select * from BATCH_JOBS where MID=$MID /* $USERNAME */ and ID=".int($ID);
		($self) = $udbh->selectrow_hashref($pstmt);
		if (not defined $self) {
			$self = { 'err'=>'Listen slappy, you probably specified the wrong username' };
			}
		}
	else {
		$self = { 'err'=>'Could not insert a new job into database' };
		}

	$self->{'%VARS'} = {};


	if ($self->{'PARAMETERS_UUID'} ne '') {
		my $pstmt = "select TITLE,BATCH_EXEC,YAML from BATCH_PARAMETERS where MID=$MID and UUID=".$udbh->quote($self->{'PARAMETERS_UUID'});
		print STDERR "$pstmt\n";
		my ($TITLE,$BATCH_EXEC,$YAML) = $udbh->selectrow_array($pstmt);
		$self->{'TITLE'} = $TITLE;
		$self->{'BATCH_EXEC'} = $BATCH_EXEC;
		$self->{'%VARS'} = YAML::Syck::Load($YAML);
		delete $self->{'BATCH_VARS'};
		}
	elsif ($self->{'BATCH_VARS'} ne '') {
		$self->{'%VARS'} = &ZTOOLKIT::parseparams( $self->{'BATCH_VARS'} );
		delete $self->{'BATCH_VARS'};
		}

	bless $self, $class;	
	if (not defined $self->{'*LM'}) { $self->{'*LM'} = $options{'*LM'}; 	}
	if (not defined $self->{'*LM'}) { $self->{'*LM'} = LISTING::MSGS->new($self->username()); }


	&DBINFO::db_user_close();

	return($self);
	}



##
## NOTE: pass ID=0 to start a new job
##
## options
##		EXEC=>
##		VARS=>
##
sub create {
	my ($class, $USERNAME, %options) = @_;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $ID = 0;
	if (not defined $options{'GUID'}) {
		warn "GUID not passed to BATCH->new() -- you should not normally do this.";
		$options{'GUID'} = &BATCHJOB::make_guid();
		}
	else {
		## we should try and lookup the GUID (make sure this isnt a dup)
		$ID = &BATCHJOB::resolve_guid($USERNAME,$options{'GUID'});
		}

	if ($options{'DOMAIN'}) { $options{'%VARS'}->{'DOMAIN'} = $options{'DOMAIN'}; }

	my $LUSERNAME = '';
	my $is_admin = 0;
	if (($options{'*LU'}) && (ref($options{'*LU'}) eq 'LUSER')) {
		$LUSERNAME = sprintf("%s",$options{'*LU'}->luser());
		$is_admin = $options{'*LU'}->is_admin();
		}
	else {
		delete $options{'*LU'};
		}
	
	if ($ID==0) {
		## NEW JOB
		my $BATCH_EXEC = undef;
		my $PRT = $options{'PRT'};
		if (not defined $PRT) { $PRT = 0; }

		if (not defined $options{'TITLE'}) { $options{'TITLE'} = "Job $options{'EXEC'}";	}
		if (not defined $options{'TITLE'}) { $options{'TITLE'} = "Job title not set";	}
		if ($options{'EXEC'} eq '') {
			return({err=>"Sorry friend, No execution command specified."});
			}

		if (not defined $options{'EXEC'}) { $options{'EXEC'} = ''; }
		if (not defined $options{'JOB_TYPE'}) { $options{'JOB_TYPE'} = ''; } ## unknown
		if ($options{'EXEC'} =~ /^(.*?)\/(.*?)$/) {	
			$BATCH_EXEC = $options{'EXEC'};
			}

		

		my ($pstmt) = &DBINFO::insert($udbh,'BATCH_JOBS',{
			USERNAME=>$USERNAME,
			LUSERNAME=>$LUSERNAME,
			MID=>$MID,
			PRT=>$options{'PRT'},
			GUID=>$options{'GUID'},
			VERSION=>int($options{'VERSION'}),
			PARAMETERS_UUID=>($options{'PARAMETERS_UUID'}||""),
			BATCH_EXEC=>$BATCH_EXEC,
			BATCH_VARS=>&ZTOOLKIT::buildparams($options{'%VARS'},1),
			TITLE=>$options{'TITLE'},
			'*CREATED_TS'=>'now()',
			STATUS=>'NEW',
			JOB_TYPE=>$options{'JOB_TYPE'},
			},sql=>1,verb=>'insert');
		$udbh->do($pstmt);
		
		$pstmt = "select last_insert_id()";
		($ID) = $udbh->selectrow_array($pstmt);
		if (defined $options{'*LU'}) {
			$options{'*LU'}->log("BATCH.$options{'EXEC'}",substr("Created Job#$ID - $options{'VARS'}",0,512),"INFO");
			}
		else {
			warn "options{'*LU'} is not set, so no entry will be added to the users access log";
			}
		}

	my $self = {};
	if ($ID>0) {
		## even if this is a new entry, we still load it from the db.
		$self = BATCHJOB->new($USERNAME,$ID);
		}
	else {
		$self = { 'err'=>'Could not insert a new job into database' };
		bless $self, $class;	
		# use Data::Dumper; print Dumper($self);
		#if (not defined $self->{'*LM'}) { $self->{'*LM'} = $options{'*LM'}; 	}
		#if (not defined $self->{'*LM'}) { $self->{'*LM'} = LISTING::MSGS->new($self->username()); }
		}

	&DBINFO::db_user_close();

	return($self);
	}




## just some code refs.. makes the code look pretty.
sub mid { return($_[0]->{'MID'}); }
sub prt { return($_[0]->{'PRT'}); }
sub username { return($_[0]->{'USERNAME'}); }
#sub luser { return($_[0]->{'LUSER'}); }
sub lusername { return($_[0]->{'LUSERNAME'}); }
sub created_gmt { return(&ZTOOLKIT::mysql_to_unixtime($_[0]->{'CREATED_TS'})); }
sub version { return($_[0]->{'VERSION'}); }

#sub luser { 
#	my ($self) = @_;
#	require LUSER;
#	my ($lu) = LUSER->new($self->username(),$self->lusername());
#	return($lu);
#	}

sub lm { return($_[0]->{'*LM'}); }

sub guid { return($_[0]->{'GUID'}); }
sub id { return($_[0]->{'ID'}); }
sub execverb { return(split(/\//,$_[0]->{'BATCH_EXEC'})); }

## does the user/creator have admin priviledges? (pulled from LUSER and set in BATCH_JOBS table)
sub is_admin { return(int($_[0]->{'IS_ADMIN'})); }	
##sub job_type { return($_[0]->{'JOB_TYPE'}); }


sub vars {
	my ($self) = @_;
	return($self->{'%VARS'});
	}

sub meta { return($_[0]->vars()); }


##
## gets an object property.
##
sub get {
	my ($self,$key) = @_;
	if (substr($key,0,1) eq '.') {
		## to reference a cgi var e.g. .REPORT
		return($self->{'%VARS'}->{substr($key,1)});
		}
	else {
		## part of the db record.
		return($self->{$key});
		}
	}



sub cleanup {
	my ($self) = @_;
	my ($JOBID) = $self->id();
	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "update BATCH_JOBS set ARCHIVED_TS=now() where MID=$MID /* $USERNAME */ and ID=$JOBID";
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}



##
##
## adds a status log to the BATCH_SLOGS table
##
sub slog {
	my ($self, $message) = @_;

	}


## 
## sets the title for a given job.
##
sub title {
	my ($self, $TITLE) = @_;

	$self->{'TITLE'} = $TITLE;
	my $udbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "update BATCH_JOBS set TITLE=".$udbh->quote($TITLE)." where MID=".$self->mid()." and ID=".$self->id();
	$udbh->do($pstmt);
	&DBINFO::db_user_close();	
	}


##
## VALID UPDATES:
##		MSG=>
##		STATUS=>'RUNNING','SUCCESS','WARNINGS','ERROR'
##		RECDONE
##		RECTOTAL
sub update {
	my ($self, %options) = @_;

	my $udbh = &DBINFO::db_user_connect($self->username());

	delete $options{'ID'};		## just for safety.. (these should never be updated)
	delete $options{'MID'};
	delete $options{'USERNAME'};
	delete $options{'GUID'};

	##
	## some fast aliases.. 
	##

	## MSG => STATUS_MSG
	if (defined $options{'MSG'}) {
		$options{'STATUS_MSG'} = $options{'MSG'}; delete $options{'MSG'};
		}
	## TOTAL => RECORDS_TOTAL
	if (defined $options{'TOTAL'}) {
		$options{'RECORDS_TOTAL'} = $options{'TOTAL'}; delete $options{'TOTAL'};
		}
	## COUNT => RECORDS_COUNT
	if (defined $options{'COUNT'}) {
		$options{'RECORDS_DONE'} = $options{'COUNT'}; delete $options{'COUNT'};
		}
	elsif (defined $options{'DONE'}) {
		$options{'RECORDS_DONE'} = $options{'DONE'}; delete $options{'DONE'};
		}
	#elsif (defined $options{'NOTES'}) {
	#	$options{'OUTPUT_NOTES'} = $options{'NOTES'}; 
	#	delete $options{'NOTES'};
	#	}

	#if ($self->{'@slogs'}) {
	#	## if we have any status logs (slogs) on update, then make sure we communicate that.
	#	$options{'HAS_SLOG'} = 1;
	#	}
	
	foreach my $k (keys %options) {
		## update our own object with any updates as well.
		$self->{$k} = $options{$k};
		}

	&DBINFO::insert($udbh,'BATCH_JOBS',{
		ID=>$self->id(),
		MID=>$self->mid(),
		%options
		},key=>['MID','ID'],update=>2,debug=>1);
	&DBINFO::db_user_close();
	return();
	}



sub get_slogid {
	my ($self) = @_;
	return(sprintf("batch-slog-%s-%d",$self->username(),$self->id()));
	}




##
## these are the fields which are normally sent via json
##
sub read {
	my ($self) = @_;

	## hmm.. we might want to eventually set more stuff up in here.
	my %RESPONSE = ();
	$RESPONSE{'started'} = &ZTOOLKIT::mysql_to_unixtime($self->{'CREATED_TS'});
	$RESPONSE{'finished'} = &ZTOOLKIT::mysql_to_unixtime($self->{'END_TS'});
	$RESPONSE{'records_done'} = $self->{'RECORDS_DONE'};
	$RESPONSE{'records_total'} = $self->{'RECORDS_TOTAL'};
	$RESPONSE{'records_error'} = $self->{'RECORDS_ERROR'};
	$RESPONSE{'records_warn'} = $self->{'RECORDS_WARN'};
	$RESPONSE{'status_msg'} = $self->{'STATUS_MSG'};
	$RESPONSE{'status'} = $self->{'STATUS'};
	$RESPONSE{'BATCH_EXEC'} = $self->{'BATCH_EXEC'};
	$RESPONSE{'GUID'} = $self->guid();

	return(%RESPONSE);	
	}


##
## this is called to create a job .. this kicks the job off in the background.
##		by running /backend/lib/batch.pl
sub start {
	my ($self) = @_;

	my ($ID) = $self->id();
	my ($USERNAME) = $self->username();
	my ($EXEC,$VERB) = $self->execverb();

	open F, ">>/tmp/job-log";
	print F "$ID $USERNAME $EXEC\n";
	close F;

	&ZOOVY::msgAppend($self->username(),"",{ 
		origin=>sprintf("batchjob.%d",$self->id()),
		verb=>"add",
		icon=>"run",
		msg=>"job.start", 
		note=>sprintf("Job #%d $EXEC $VERB is starting",$self->id()),
		});

	## NOTE: technically report doesn't need any of this stuff.. except $ID .. 
	##	but we pass it for pretty URI and ps -aux output
	return(0);
	}


##
## this still needs some work.
##
sub finish {
	my ($self,$status,$statusMsg) = @_;

	if ($status eq 'SUCCESS') { $status = 'END-SUCCESS'; }
	if ($status eq 'ERROR') { $status = 'END-ERRORS'; }

	if ($status eq '') {
		warn "Called BATCHJOB->finish without setting status";
		}
	if ($status !~ /^END/) {
		Carp::cluck("BATCHJOB->finish status:$status\n");
		$status = 'END';
		}
	$self->update('STATUS'=>$status,'STATUS_MSG'=>$statusMsg,'END_TS'=>&ZTOOLKIT::mysql_from_unixtime(time()));

	my ($exec,$verb) = $self->execverb();
	if (not $self->{'finished'}) {
		## cleanup (only send notification once)
		$self->{'finished'}++;
		&ZOOVY::msgAppend($self->username(),"",{ 
			origin=>sprintf("batchjob.%d",$self->id()),
			verb=>"update",
			icon=>"done",
			msg=>"job.finished", 
			note=>sprintf("Job #%d $exec $verb has completed",$self->id()),
			});
		
		
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		if ($self->{'PARAMETERS_UUID'} ne '') {
			my ($MID) = $self->mid();
			my $qtUUID = $udbh->quote($self->{'PARAMETERS_UUID'});
			my $JOBID = int($self->id());
			my $pstmt = sprintf("update BATCH_PARAMETERS set LASTRUN_TS=now(),LASTJOB_ID=$JOBID where MID=$MID and UUID=$qtUUID");
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}

		&DBINFO::db_user_close();
		}

	


	return(0);
	}

1;