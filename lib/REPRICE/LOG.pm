package REPRICE::LOG;

use strict;

use lib "/backend/lib";
require ZTOOLKIT;
##
## a text log useful for 
##

## LINE FORMAT:
##	DATE|MKT|SELLER|MSGTYPE|key1=val1&key2=val2

#sub username { return($_[0]->{'_USERNAME'}); }
#sub product { return($_[0]->{'_PRODUCT'}); }
#sub sku { return($_[0]->{'_SKU'}); }

sub ts2timestr { return(&ZTOOLKIT::base62($_[0])); }
sub timestr2ts { return(&ZTOOLKIT::unbase62($_[0])); }

sub TO_JSON {
	my ($self) = @_;
	my @DATA = ();
	foreach my $line (@{$self}) { 
		my %ref = %{$line->[3]};
		$ref{'ts'} = $line->[0];
		$ref{'mkt'} = $line->[1];
		$ref{'msg'} = $line->[2];
		if (defined $ref{'fob'}) { $ref{'fob'} = int($ref{'fob'}*100); }
		if (defined $ref{'ship'}) { $ref{'ship'} = int($ref{'ship'}*100); }
		if (defined $ref{'item'}) { $ref{'item'} = int($ref{'item'}*100); }
		if ((defined $ref{'fbp'}) && (index($ref{'fbp'},'-')>=0)) {
			(my $low,$ref{'fbp'}) = split(/\-/,$ref{'fbp'}); $ref{'fbp'} = int($ref{'fbp'}); 
			}

		push @DATA, \%ref;
		}
	return(\@DATA);
	}

## how many lines are in the current txlog
## should really be called "count"
sub new {
	my ($class) = @_;
	my $self = [];
	bless $self, 'REPRICE::LOG';
	return($self);
	}

sub test {
	my ($self, $str) = @_;
	return($str);
	}

sub append {
	my ($self, $ts, $mkt, $type, $ref) = @_;
	push @{$self}, [ $ts, $mkt, $type, $ref ];
	return($self);
	}

sub deserialize {
	my ($self, $buffer) = @_;
	foreach my $txtline (split(/[\n]+/,$buffer)) {
		my ($timestr,$mkt,$type,$refstr) = split(/\|/,$txtline,4);
		my $ref = &ZTOOLKIT::parseparams($refstr);
		unshift @{$self}, [ &REPRICE::LOG::timestr2ts($timestr),$mkt,$type, $ref ];
		}
	return($self);
	}

sub filter {
	my ($self, %filter) = @_;
	my $new = [];
	return($new);
	}

sub as_string {
	my ($self) = @_;
	my $str = '';
	foreach my $line (@{$self}) {
		$str .= join("|",$line->[0],$line->[1],$line->[2],&ZTOOLKIT::buildparams($line->[3]))."\n";
		}
	return($str);
	}




sub serialize {
	my ($self) = @_;

	my $txt = '';
	foreach my $line (@{$self}) {
		$txt = sprintf("%s|%s|%s|%s",&REPRICE::LOG::ts2timestr($line->[0]),$line->[1],$line->[2],&ZTOOLKIT::buildparams($line->[3]))."\n$txt";
		}
	return($txt);
	}

## merge one rpl into another! 
sub merge {
	my ($self, $rpl) = @_; foreach my $ref (@{$rpl}) { push @{$self}, $ref; } return($self);
	}


1;

__DATA__
	my $self = {};
	my %UNIQUES = ();
	foreach my $line (split(/[\n\r]+/,$buffer)) {
		if ($line =~ /^([A-Z\-]*)\(([\d]+)\)\?(.*?)$/) {
			my ($UNI,$TS,$PARAMS) = ($1,$2,$3);
			if ($UNI eq '') { 
				push @LINES, $line; 
				}
			elsif (not defined $UNIQUES{$1}) { 
				push @LINES, $line;
				$UNIQUES{$UNI} = $line;
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

