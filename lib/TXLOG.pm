package TXLOG;

use strict;

# perl -e 'use lib "/backend/lib"; use TXLOG; my ($tx) = TXLOG->new(); $tx->add(0,"","non"=>1); $tx->add(0,"product","msg"=>"this is the product message"); $tx->add(0,"asdf","msg"=>"xyz"); $tx->add(0,"product","msg"=>"updated product message"); $tx->add(0,"","non"=>2); $tx->add(0,"product"); print $tx->serialize(); use Data::Dumper; print Dumper($tx->get("product")); '


##
## TXLOG is a handy utility that lets a series of error messages be stored in a varchar or text based field in mysql
##		what makes them particularly interesting is the logs can be appended to by simply prepending the new log line and
##		letting old logs "fall away" ex:
##			update XYZ set LOG=concat($qtNEWLINE,LOG);
##
##		functions;
##		* new($buffer)			: buffer to deserialize (from database)
##		* serialize()			: returns a buffer suitable for append and/or update, overwrite
##		* parseline($line)	: returns $unique,$timestamp,$paramsref
##		* get($unique) 		: gets the most recent unique occurrent ex: 'product', 'image'
##		* add($ts,$unique,%params)	: if unique is blank then it's treated a non-unique product
##		* addline				: a direct call (non object method) for creating a suitable line to the db directly.
##

use lib "/backend/lib";
require ZTOOLKIT;
##
## a text log useful for 
##

## how many lines are in the current txlog
## should really be called "count"
sub count {
	return(scalar(@{$_[0]->{'@'}}));
	}

sub new {
	my ($class,$buffer, %options) = @_;
	my @LINES = ();

	my $self = {};
	my %UNIQUES = ();
	my %DUPCHECK = ();
	foreach my $line (split(/[\n\r]+/,$buffer)) {

		next if ($DUPCHECK{$line}++);		## don't ever put identical lines in (even if they exist in the log);

		if ($line =~ /^([A-Z\-]*)\(([\d]+)\)\?(.*?)$/) {
			my ($UNI,$TS,$PARAMS) = ($1,$2,$3);
			if ($UNI eq '') { 
				push @LINES, $line; 
				}
			elsif (not defined $UNIQUES{$1}) { 
				push @LINES, $line;
				$UNIQUES{$UNI} = $line;
				}
			elsif ((defined $options{'detail'}) && ($options{'detail'})) {
				## history
				push @LINES, $line.'&_detail=1';
				}
			else {
				## do not append
				}
			}			
		}

	$self->{'@'} = \@LINES;
	$self->{'%'} = \%UNIQUES;

	bless $self, 'TXLOG';
	return($self);
	}


## SYNTAX: my $TX = TXLOG->new()->lmsgs($lm,'group')
##		PSTMT : TXLOG=concat('.$udbh->quote(TXLOG->new()->lmsgs($lm,'group')->serialize()).',TXLOG)

## This is mostly deprecated use from_lm
sub lmsgs { my ($self,$lm,$group) = @_; $lm->append_txlog($self,$group); return($self); }

## TXLOG->new()->lmsgs('group',$lm,['SUCCESS','INFO','WARN'])
sub from_lm {
	my ($self,$group,$lm,$msgtypes) = @_;

	my $ts = time();
	my $MSGTYPES = [ 'WARN','ERROR','ISE','SUCCESS','FAIL','PAUSE','SKIP','STOP' ];
	if (defined $msgtypes) { $MSGTYPES = $msgtypes };

	foreach my $msg (@{$lm->msgs()}) {
		my ($msgref,$status) = &LISTING::MSGS::msg_to_disposition($msg);
		my $ignore = 0;

		if (scalar(@{$MSGTYPES})>0) {
			$ignore = 1;
			foreach my $msgtype (@{$MSGTYPES}) {
				if ($msgref->{'_'} eq $msgtype) { $ignore = 0; last; }
				}
			}

		if (not $ignore) {
			delete $msgref->{'!'};		## delete soft status
			$self->add($ts,$group,%{$msgref});
			}
		}

	return($self);
	}
##
##
sub lines { return($_[0]->{'@'}); }
sub uniques { return(values %{$_[0]->{'%'}}); }

sub parseline {
	my ($line) = @_;

	if ($line =~ /^([A-Z\-]*)\(([\d]+)\)\?(.*?)$/) {
		my ($UNI,$TS,$PARAMSTR) = ($1,$2,$3);
		my $PARAMSREF = &ZTOOLKIT::parseparams($PARAMSTR);
		return($UNI,$TS,$PARAMSREF);
		}
	}

sub get {
	my ($self, $UNIQUE) = @_;

	$UNIQUE=uc($UNIQUE);
	return(&TXLOG::parseline($self->{'%'}->{$UNIQUE}));
	}

##
## returns an array of all non unique identifiers
##
sub getununique {
	my ($self) = @_;

	my @RESULTS = ();
	foreach my $line (@{$self->{'@'}}) {
		if ($line =~ /^\(/) {
			my ($uni,$ts,$ref) = &TXLOG::parseline($line); 
			push @RESULTS, [ $ts, $ref ] ;
			}
		}
	
	return(\@RESULTS);
	}






sub addline {
	my ($TS, $UNIQUE, %params) = @_;	
	if ($TS == 0) { $TS = time(); }
	$UNIQUE = uc($UNIQUE);
	$UNIQUE =~ s/[^A-Z\-]+//gs;
	foreach my $k (keys %params) {
		## strip out hard returns
		$params{$k} =~ s/[\n\r]+/ /gs;
		}
	my $line = sprintf("%s(%d)?%s",$UNIQUE,$TS,&ZTOOLKIT::buildparams(\%params,1))."\n";
	return($line);
	}


## SAMPLE:
## my $qtTXMSG = $udbh->quote(TXLOG->new()->add($CREATED,"launch","+"=>$REASON)->serialize());
## update .. set TXLOG=concat($qtTX,TXLOG) 

sub add {
	my ($self, $TS, $UNIQUE, %params) = @_;
	
	shift @_;
	my $line = &TXLOG::addline(@_);

	$UNIQUE = uc($UNIQUE);
	$UNIQUE =~ s/[^A-Z]+//gs;
	chomp($line);
	unshift @{$self->{'@'}}, $line; 
	$self->{'%'}->{$UNIQUE} = $line;

	return($self);
	}


sub serialize {
	my ($self) = @_;
	my $c = '';
	foreach my $line (@{$self->{'@'}}) {
		$c .= "$line\n";
		}
	return($c);
	}




1;