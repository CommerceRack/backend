package LISTING::MSGS;

use strict;
use POSIX;

use lib "/backend/lib";
use TXLOG;

##	need to be able to contain errors in several differnet formats, and switch between them acceptable formats are:
##		"ERROR|message"	or 	"ERROR|msg=message"
##		"SUCCESS|message"	or		"SUCCESS|msg=message"
##		parsing rules:
##			the zero element following a | split (if it doesnot contain a =) will be treated as the status/result
##			the last element following a | split (if it doesnot contain a = in the first 10 characters) will be treated as the msg
##
##		more detail can be included (if necessary)
##		"FAIL"=>"ERROR"
##		"FAIL-SOFT" => "ERROR"
##		"FAIL-FATAL" => "ERROR"
##		"SUCCESS"	=> "SUCCESS"
##		"SUCCESS-WARNING"	=> "SUCCESS"
##
## 	some types like powerlister also like:
##		"WAIT","PAUSE"
##		"STOP","END"
##
##		in addition - additional information may be returned in an array of messages these messages are considered
##		useful but "non-essential" they are types:
##		"WARN|"	
##		"INFO|"
##		"DEBUG|TRACE:1-5"
##	
##
##	in the reverse sense a generic "ERROR" will be treated as "FAIL-FATAL" unless it has an associated CODE
##	whereas "SUCCESS" will simply mean "SUCCESS"
##
##
##	other data which can be passed (pipe delimited) includes:
##		src=ISE,PREFLIGHT,ZLAUNCH,TRANSPORT,MKT,MKT-LISTING,MKT-ACCOUNT
##			(if not known then TRANSPORT will be used)
##		code=#### 	
##			(this is a numeric code to indicate a specific type of error)
##		id=23456
##			(the listing id which was created as a result, usually this replaces the message)
##		uuid=####
##			(database id)
##		retry=##	
##			(how many attempts we can make before we treat this as a fatal error)
##		duration=# (days or -1 for gtc)
##		expires=#  (gmt time when the listing will end)
##
##		additional key value pairs may also be included to encode additional data.
##		
##		
##		
##	when returned in merged hashref form the following keys are set:
##		_ => detailed status (e.g. FAIL-SOFT instead of ERROR)
##		! => simple SUCCESS|ERROR
##		+ => message
##

##
## TYPES OF MESSAGES (COMMONLY ACCEPTED MEANINGS)
##		PROBLEMS(S)
##			ERROR			: a general error message, may be used for flow control, non-descriptive of outcome 
##							  (could be success or fail)
##			FAIL			: the operation did not complete successfully (reason specified in error)
##			FAIL-SOFT	: deprecated, replaced by several different FLOW CONTROL messages
##			FAIL-FATAL	: deprecated, replaced by "FATAL"
##			ABORT			: the operation was started and aborted (reason contained in error)
##			FATAL			: the operation was started and crashed (abort assumes it was undone, fatal means things may be in a crashed state)
##			CRASHED		: things went wrong, and were definitely left in a crashed state.
##			ISE			: a failure that is definitely NOT the responsibility or fault of the user 
##			YOUERR		: user error
##			APPERR		: requested parameters/application failed
##			APIERR		: an api communication error occurred
##			ISEERR		: a well formatted response to an internal server error. (same as an ISE but well structured)
##		WARNING(S)
##			WARN			: a non failure, but alertable condition
##		STATUS
##			INFO			: a general message (should always be displayed)
##			DETAIL		: a detail message -- can conditionally be displayed based on preferences. 
##			HELP			: how to ask for help - information/links about what happened (guaranteed to contain 'meta' than info)
##			HINT			: recommendation about how to improve this action in the future. 1
##			TIP			: recommendation about something else the user might like. 
##		 	TODO			: a recommendation on something the use should do to avoid this (dismissable)
##			TASK			: a recommendation that the user MUST perform (more severe)
##			ALERT			: a very severe warning that should (if possible) be displayed as a popup with a dismiss.
##			DEPRECATED	: (warning) this feature will be removed or very different in the future. 
##			FUTURE		: this feature will be changed in the future.
##			SUMMARY		: a summary of events performed (may combine success/fails)
##		FLOW+STATUS:	(used for aggregating % record tracking win/fail velocity)
##			GOOD			: helpful advice about the configuration (positive) ex: todo list is small, this will be quick.
##			BAD			: helpful advice about the configuration (negative) ex: todo list is huge, this will be painful.
##		FLOW
##			END			: general 'we finished' message (does not indicate state)
##			STOP			: task was intentionally not done ex: a successful end with nothing done. 
##			HALT			: task was not done, due to error during run	 ex: database server went away.
##			WAIT			: task was not done, due to time contrainted action ex: cannot close, item has not ended.
##			PAUSE			: task was not done, due to external constraint  ex: inventory not available
##			SKIP			: task was not done, avoided due to configuration. 
##			WIN			: the counterpart to a fail (same as SUCCESS, but also often used in a subsystem)
##			SUCCESS		: a confirmation was received that action was performed as requested. 
##		DEVELOPER(s)
##			DEBUG			: developer related mumbo jumbo and political rants. 
##
##


##
## the TO_JSON method is used by JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($R);
##	(PAGE::JQUERY)
##
sub TO_JSON {
	my ($self) = @_;

	return($self->msgs());
	}


##
## 
##
sub status_as_txlog {
	my ($self, %params) = @_;

	my $statusref = $params{'@'};
	if (not defined $statusref) {
		die("We need a '\@' parameter with a list of status messages");
		$statusref = ['WARN','ERROR','ISE','SUCCESS','FAIL','PAUSE','SKIP','STOP','STATUS'];
		}
	my %STATUS_WHITELIST = ();
	foreach my $status (@{$statusref}) {
		$STATUS_WHITELIST{$status}++;
		}
	
	my ($tx) = TXLOG->new();
	my $ts = time();
	foreach my $msg (@{$self->{'@MSGS'}}) {

		my ($msgref,$status) = &msg_to_disposition($msg);
		# use Data::Dumper; print Dumper($msgref);
		my $ignore = 0;
		if ( ($STATUS_WHITELIST{ $msgref->{'!'} }) || ($STATUS_WHITELIST{ $msgref->{'_'} })) {
			my $group = $msgref->{'_'};
			delete $msgref->{'!'};		## delete soft status
			delete $msgref->{'_'};
			$tx->add($ts,$group,%{$msgref});
			# use Data::Dumper; print Dumper($tx);
			}
		}
	return($tx);
	}

##
## this dumps all non-debug, msgs into a txlog object for dumping into a database
##
sub append_txlog {
	my ($self,$txlog,$unique, %options) = @_;

	my $ts = int($options{'ts'});
	foreach my $msg (@{$self->{'@MSGS'}}) {
		my ($msgref,$status) = &msg_to_disposition($msg);
		my $ignore = 0;
		if ($msgref->{'_'} =~ /^(WARN|ERROR|ISE|SUCCESS|FAIL|PAUSE|SKIP|STOP)$/) { 
			delete $msgref->{'!'};		## delete soft status
			$txlog->add($ts,$unique,%{$msgref});
			}
		}
	return($txlog);
	}


sub pid {
	my ($self, $pid) = @_;
	if (defined $pid) { $self->{'_PID'} = $pid; }
	return($self->{'_PID'});
	}


##
## not sure what this does.
##
sub set_debug {
	my ($self) = @_;
	}

sub msgs { 
	if (not defined $_[0]->{'@MSGS'}) { $_[0]->{'@MSGS'} = []; }
	return($_[0]->{'@MSGS'}); 
	}

sub set_batchjob {
	my ($self,$bj) = @_;
	$self->{'*BJ'} = $bj;
	return();
	}


##
## note: we might want to reformat this a bit in the future so it displays a bit prettier
##
sub as_string {
	my ($self) = @_;

	my $c = '';
	if (not defined $_[0]->{'@MSGS'}) { $_[0]->{'@MSGS'} = []; }
	foreach my $msg (@{$self->{'@MSGS'}}) {
		$c .= "$msg\n";
		}
	return($c);
	}

##
## for merging one $lm into another.
##
sub merge {
	my ($self,$lm,%options) = @_;

	my $MSGS = undef;
	if ((scalar(keys %options)==0) || ($options{'_raw'})) {
		## short circut -- no options, just raw copy it.
		$MSGS = $lm->msgs();
		}
	else {
		## reformat the messages (adding identifiers, rewrite statuses, etc.)
		my @MSGS = ();
		foreach my $msg (@{$lm->msgs()}) {
			my ($msgref,$status) = &msg_to_disposition($msg);
			## note: $options are always lowercase because hashref_to_msg needs them that way
			foreach my $k (keys %options) { 
				next if (substr($k,0,1) eq '_'); ## ignore _ ex: _log=>1 parameters
				next if (substr($k,0,1) eq '%'); ## ignore % ex: %mapstatus
				$msgref->{lc($k)} = $options{$k}; 
				}

			## %mapstatus '%mapstatus'=>{ 'ERROR'=>'PRODUCT-ERROR', 'STOP'=>'PRODUCT-STOP' }
			##	useful when we're merging a plm into a global lm.
			if (not defined $options{'%mapstatus'}) {
				}
			elsif ($options{'%mapstatus'}->{$status}) {
				$status = $options{'%mapstatus'}->{$status};
				}
			if (defined $options{'prefix'}) { $status = $options{'prefix'}.'-'.$status; }
			push @MSGS, &hashref_to_msg($status,$msgref);
			}
		$MSGS = \@MSGS;
		}

	foreach my $msg (@{$MSGS}) {
		push @{$self->{'@MSGS'}}, $msg;
		}

	if (not defined $options{'_log'}) {
		## append to the log file if one is set.
		$options{'_log'} = (defined $self->{'LOGFILE'})?1:0;
		}

	if ( ($options{'_log'}) && (defined $self->{'LOGFILE'}) ) {
		my $REFID = sprintf("%s.%s",$self->{'REFID'},$options{'_refid'});
		open F, ">>$self->{'LOGFILE'}";
		foreach my $msg (@{$MSGS}) {
			$msg =~ s/[\n\r]+//gs;
			print F sprintf("%s\t%s\t%s\t%s\n",$self->{'LOGDATE'},$REFID,$msg,$self->{'LUSER'});
			}
		close F;
		}

	# use Data::Dumper; print STDERR Dumper($self);
	return($self);
	}


##
## a wrapper around pooshmsg when we implicitly want to log to console!
##
sub showmsg {
	my ($self,$msg) = @_;
	## eventually we might do a caller here... who knows!?
	return($self->pooshmsg($msg));
	}

##
## same as poosh, but does a raw message 
##
sub pooshmsg {
	my ($self,$msg) = @_;

	$msg =~ s/[\n\r]+/; /gs;
	if (not defined $self->{'@MSGS'}) { $self->{'@MSGS'} = []; }
	push @{$self->{'@MSGS'}}, $msg; 

	if (defined $self->{'STDERR'}) {
		print STDERR "$self->{'LOGDATE'}\t".($self->pid()?($self->pid()."\t"):"")."$msg\n";
		}

	if (not defined $self->{'LUSER'}) { $self->{'LUSER'} = ''; }
	if (not defined $self->{'REFID'}) { $self->{'REFID'} = ''; }

	if (defined $self->{'LOGFILE'}) {
		open F, ">>$self->{'LOGFILE'}";
		$msg =~ s/[\n\r]+//gs;
		print F sprintf("%s\t%s\t%s\t%s\n",$self->{'LOGDATE'},$self->{'REFID'},$msg,$self->{'LUSER'});
		close F;
		}

	if (defined $self->{'*BJ'}) {
		$self->{'*BJ'}->slog($msg);
		}

	return();
	}

##
## adds a status + text + hash of params into a message object.
##
sub poosh {
	my ($self,$status,$text,%more) = @_;
	
	if (not defined $self->{'@MSGS'}) { $self->{'@MSGS'} = []; }
	if (defined $text) { $more{'+'} = $text; }
	$self->pooshmsg(&hashref_to_msg($status,\%more));

	return();
	}


##
## converts detailed "result/status" messages into simple ERROR or SUCCESS
##
sub _simplify_status {
	my ($status) = @_;

	my $simple = undef;

	if (index($status,'-')>0) { $simple = $status = substr($status,0,(index($status,'-'))); }

	if ($status eq 'ERROR') { $simple = 'ERROR'; }
	elsif ($status eq 'SUCCESS') { $simple = 'SUCCESS'; } 
	elsif (($status eq 'WARN') || ($status eq 'INFO') || ($status eq 'DEBUG')) { $simple = ''; } 
	elsif ($status eq 'ISE') { $simple = 'ERROR'; }
	elsif ($status eq 'FAIL') { $simple = 'ERROR'; }
	elsif ($status eq 'STATUS') { $simple = 'STATUS'; }

	return($simple);
	}


##
## had status - e.g. "STOP"
##		also supports array ref ['STOP','PAUSE']
##
sub had {
	my ($self,$needstatus) = @_;
	
	my $regex = undef;
	if (ref($needstatus) eq '') {
		## convert scalar context into array
		$regex = '^'.$needstatus.'\|';
		}
	else {
		$regex = '^('.join("|",@{$needstatus}).')\|';
		}
	$regex = qr/$regex/;
	# print "REGEX: $regex\n";

	my $result = undef;
	## array context
	foreach my $msg (reverse @{$self->{'@MSGS'}}) {
		# print "MSG:$msg\n";
		next if (defined $result);
		next unless ($msg =~ /$regex/);	## use a regex 

		my ($thisref,$thisstatus) = &msg_to_disposition($msg);
		$result = $thisref;
		}		
	
	return($result);
	}


##
## takes an array of messages
##	and looks for essential "STOP", "WAIT" messages -- in addition "ERROR" or "FAIL" messages will also trigger
##
sub can_proceed {
	my ($self) = @_;

	my $can_proceed = 1;
	if (grep(/^(ISE|PAUSE|END|HALT|STOP|SKIP|WAIT|ERROR|FAIL-SOFT|FAIL-FATAL)\|/o,@{$self->{'@MSGS'}})) { $can_proceed = 0; }
	return($can_proceed);
	}

##
## takes an array of messages
## and which looks for essential "FAIL" messages 
##		NOTE: a lack of success messages DOES NOT indicate a failure (it could simply indicate safe to continue)
##
sub has_failed {
	my ($self) = @_;	
	
	my $has_error = 0;
	if (grep(/^(ERROR|ISE|FAIL-SOFT|FAIL-FATAL)\|/,@{$self->{'@MSGS'}})) { $has_error++; }
	return($has_error);
	}

##
## takes an array of messages
## and which looks for essential "SUCCESS" messages 
##		NOTE: a lack of success messages DOES NOT indicate a failure.
##		## had_win
sub has_win {
	my ($self) = @_;
	my $has_success = 0;
	if (grep(/^(SUCCESS|SUCCESS-WARNING)\|/,@{$self->{'@MSGS'}})) { $has_success++; }
	return($has_success);
	}

##
## weed's through the messages looking for either the last success or failure message, then returns
##	it as a hashref
##
sub whatsup {
	my ($self) = @_;
	
	my @ar = grep(/^(SUCCESS|SUCCESS-WARNING|ERROR|FAIL-SOFT|FAIL-FATAL)\|/,@{$self->{'@MSGS'}});
	
	my $ref = undef;
	if (scalar(@ar)) {
		($ref,my $status) = &LISTING::MSGS::msg_to_disposition(pop @ar); # we only look at the last message
		}

	return($ref);
	}


##
##	returns a hash (containing ! and _ variables), and the "result/status" of the operation (which is the _ variable) 
##
sub msg_to_disposition {
	my ($msg) = @_;

	my @AR = split(/\|/,$msg);
	
	my %hash = ();

	my $i = 0;
	foreach my $piece (@AR) {
		if ($i == 0) { 
			$hash{'_'} = $piece;
			$hash{'!'} = &LISTING::MSGS::_simplify_status($piece);
			}
		elsif (($i<0) || (substr($piece,0,1) eq '+')) {
			$hash{'+'} .= ((defined $hash{'+'})?"|":"").$piece;
			$i = -1;
			}
		else {
			my ($k,$v) = split(/[\:=]/,$piece,2);
			$hash{$k} = $v;
			}
		if ($i>=0) { $i++; }
		}
		
	return(\%hash, $hash{'_'});
	}


##
##	returns a hash (containing ! and _ variables), and the "result/status" of the operation (which is the _ variable) 
##
sub OLD20121014msg_to_disposition {
	my ($msg) = @_;

	my @AR = split(/\|/,$msg);
	
	my %hash = ();
	my $status = undef;

	if (index($AR[0],'=')==-1) {
		## if the first element doesn't have an = then it's the status ex: SUCCESS, FAIL, WIN , etc.
		$status = shift @AR;
		$hash{'_'} = $status;
		}

	if (substr($AR[scalar(@AR)-1],0,1) eq '+') {
		## leading + on the last element indicates it's a message.
		$hash{'+'} = substr(pop @AR,1);
		}

	foreach my $kv (@AR) {
		my ($k,$v) = undef;
		($k,$v) = split(/[:=]{1,1}/,$kv,2);
		$hash{lc($k)} = $v;
		}
	if (not defined $status) {
		$status = $hash{'_'}; 
		}
	$hash{'!'} = &LISTING::MSGS::_simplify_status($status);
	return(\%hash, $status);
	}

##
## takes something like:
##		"SUCCESS",{ key=>value }
##		undef, { _=>"SUCCESS", key=>value }
##	returns a scalar:
##		"SUCCESS|key=value"
##
sub hashref_to_msg {
	my ($status,$hashref) = @_;
	my $str = '';
	## can also pass blank status and just use '_'=>SUCCESS as the handler (this makes it easy to keep things in a hash)
	if (not defined $status) { $status = $hashref->{'_'}; }
	$str = "$status|";
	foreach my $k (keys %{$hashref}) {
		next if ($k eq '_');		# this is the same as "status", contains detailed status.
		next if ($k eq '!'); 	# this is the summarized status (this should never be set unless _ is also set)
		next if ($k eq '+');
		my $x = "$k=$hashref->{$k}";
		$x =~ s/\|/~/go;	# convert pipes to tildes.
		$str .= "$x|";
		}
	chop($str);	# remove trailing |
	if (defined $hashref->{'+'}) {
		$str .= "|+$hashref->{'+'}";
		}
	return($str);
	}


## 
## usually this is passed something like the powerlister id, which is then stored in the logfile.
##
sub msg_set_refid {
	my ($self,$refid) = @_;
	$self->{'REFID'} = $refid;	
	}


##
## should we output to the console (pass 1/0 to set, or undef to check)
##
sub console {
	if ($_[1]) { $_[0]->{'STDERR'} = int($_[1]); }
	return($_[0]->{'STDERR'});
	}


sub logdate {
	my ($self) = @_;
	$self->{'LOGDATE'} = POSIX::strftime("%Y%m%d%H%M%S",localtime(time()));
	return($self->{'LOGDATE'});
	}

##
## this method is typically passed something like:
##		"~/powerlister-%YYYYMM%.log"
##
sub msg_set_logfile {
	my ($self,$logfile) = @_;

	$self->logdate();
	if ($logfile =~ /\%YYYYMM\%/) {
		# if we have filename-%YYYYMM% then we replace that with the current yearmonth
		my $yyyymm = POSIX::strftime("%Y%m",localtime(time()));
		$logfile =~ s/\%YYYYMM\%/$yyyymm/;
		}
	if (substr($logfile,0,1) eq '~') {
		# ~ means we're accessing users home directory.
		$logfile = substr($logfile,1);	# remove leading ~
		if (substr($logfile,0,1) eq '/') { $logfile = substr($logfile,1); } 	# remove leading /
		$logfile = &ZOOVY::resolve_userpath($self->{'USERNAME'})."/".$logfile;
		}
	# print STDERR "LOGFILE:$logfile\n";
	$self->{'LOGFILE'} = $logfile;
	if (! -f $logfile) {
		open F, ">>$logfile";
		print F "";
		close F;
		chown $ZOOVY::EUID,$ZOOVY::EGID, $logfile;
		chmod 0666, $logfile;
		}
	}


##
## seems like username will come in handy later.. not sure why though!
##
sub new {
	my ($CLASS,$USERNAME,%options) = @_;	

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	if (defined $options{'@MSGS'}) {
		$self->{'@MSGS'} = $options{'@MSGS'};
		}
	else {
		$self->{'@MSGS'} = [];
		}

	if (defined $options{'stderr'}) {
		$self->{'STDERR'} = $options{'stderr'};
		}

	if (defined $options{'refid'}) {
		$self->{'REFID'} = $options{'refid'};
		}
	else {
		$self->{'REFID'} = $$;
		}

	## the focus pid
	if (defined $options{'pid'}) {
		$self->{'_PID'} = $options{'pid'};
		}

	bless $self, 'LISTING::MSGS';

	if (defined $options{'logfile'}) {
		$self->msg_set_logfile($options{'logfile'});
		}

	return($self);
	}

##
## empties the message queue
##
sub flush {
	$_[0]->{'@MSGS'} = [];
	}

1;
