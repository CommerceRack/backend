package BATCHJOB::IMPORT::RULES;

use strict;
use lib "/backend/lib";
use DBINFO;
use ZSHIP::RULES;

sub import {
	my ($bj,$fieldsref,$lineref,$optionsref) = @_;

	my ($USERNAME,$MID,$LUSERNAME,$PRT) = ($bj->username(),$bj->mid(),$bj->lusername(),$bj->prt());
		
	use Data::Dumper;
	print STDERR Dumper($fieldsref,$optionsref);
	#print STDERR "$USERNAME: \n";
	#print STDERR Dumper($fieldsref);
	#print STDERR Dumper($lineref);
	my $linecount = 0;
	if (defined $optionsref->{'PRT'}) {
		$PRT = int($optionsref->{'PRT'});
		}

	# my $metaref = $bj->meta(); print Dumper($metaref);

	my $rows_count = scalar(@{$lineref});
	my $rows_done = 0;

	# my ($LU) = LUSER->new($USERNAME,$LUSERNAME);

	my $ERROR = undef;
	my %RULES = ();
	foreach my $line ( @{$lineref} ) {
		$linecount++;

		my $RULESET = undef;
		my $RULEREF = {};

		my %DATA = ();
		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {
			$DATA{ uc($fieldsref->[$pos]) } = $line->[$pos];			
			$pos++;  # move to the next field that we should parse
			}

		
		if ((not defined $ERROR) && ($DATA{'%RULESET'} eq '')) {
			## error 
			$ERROR = "line[$linecount] Missing or blank %RULESET column";
			my $has_data = 0;
			foreach my $k (keys %DATA) {
				if ($DATA{$k} ne '') { $has_data++; }
				}
			if (not $has_data) { 
				$ERROR = "line[$linecount] appears to be blank."; 
				}
			}

		
		if (defined $ERROR) {
			}
		elsif ($DATA{'%TYPE'} eq '') {
			## error
			$ERROR = "line[$linecount] Missing or blank %TYPE column";
			}
		elsif ($DATA{'%TYPE'} eq 'COUPON') {
			$RULESET = "COUPON-".$DATA{'%RULESET'};
			$RULEREF->{'CODE'} = $DATA{'%RULESET'};
			$RULEREF->{'HINT'} = $DATA{'NAME'};
			}
		elsif ($DATA{'%TYPE'} eq 'SHIP') {
			$RULESET = "SHIP-".$DATA{'%RULESET'};
			$RULEREF->{'SCHEDULE'} = $DATA{'SHIP_SCHEDULE'};
			}
		elsif ($DATA{'%TYPE'} eq 'UBER') {
			$RULESET = $DATA{'%RULESET'};
			$RULEREF->{'CODE'} = $DATA{'UBER_GROUP'};
			$RULEREF->{'IMAGE'} = $DATA{'UBER_IMAGE'};
			$RULEREF->{'TAX'} = $DATA{'UBER_TAX'};
			$RULEREF->{'WEIGHT'} = $DATA{'UBER_WEIGHT'};
			}
		else {
			$ERROR = "line[$linecount] unknown %TYPE column \'$DATA{'%TYPE'}\'";
			}

		next if ($ERROR);

		$RULEREF->{'NAME'} = $DATA{'NAME'};
		$RULEREF->{'MATCH'} = $DATA{'MATCH'};
		$RULEREF->{'MATCHVALUE'} = $DATA{'MATCHVALUE'};
		$RULEREF->{'FILTER'} = $DATA{'FILTER'};
		$RULEREF->{'EXEC'} = $DATA{'EXEC'};
		$RULEREF->{'VALUE'} = $DATA{'EXECVALUE'};
		$RULEREF->{'CREATED'} = &ZTOOLKIT::mysql_from_unixtime(time());
		$RULEREF->{'CREATED-FROM'} = "CSV/JOB-".$bj->id()."/".$bj->lusername();
		
		foreach my $k (keys %{$RULEREF}) {
			$RULEREF->{$k} =~ s/^[\s]+//g; 	# strip leading space
			$RULEREF->{$k} =~ s/[\s]+$//g; 	# strip trailing space
			}

		if (not defined $RULES{ $RULESET }) {
			$RULES{$RULESET} = [];
			}
		push @{$RULES{$RULESET}}, $RULEREF;

		if (($rows_done++%5)==0) {
			$bj->progress($rows_done,$rows_count,"Updated Rules");
			}
		}

	if (defined $ERROR) {
		$bj->slog("ERR $ERROR");
		}
	else {
		print STDERR Dumper(\%RULES);
		&ZSHIP::RULES::savebin($bj->username(),$bj->prt(),\%RULES);
		$bj->slog("updated rules");		
		}

	};


1;
__DATA__





1;
