package BATCHJOB::IMPORT::CUSTOMER;

use strict;
use lib "/backend/lib";
require CUSTOMER;
require CUSTOMER::ADDRESS;

sub parsecustomer {
	my ($bj,$fieldsref,$lineref,$optionsref) = @_;

	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());
	

	use Data::Dumper;
	print STDERR Dumper($fieldsref,$optionsref);
	#print STDERR "$USERNAME: \n";
	#print STDERR Dumper($fieldsref);
	#print STDERR Dumper($lineref);
	print STDERR Dumper($optionsref);
	my $linecount = 0;
	if (defined $optionsref->{'PRT'}) {
		$PRT = int($optionsref->{'PRT'});
		}

	my $rows_count = scalar(@{$lineref});
	my $rows_done = 0;

	foreach my $line ( @{$lineref} ) {
		my %billhash = ();
		my %shiphash = ();
		my %metahash = ();
	
		my $EMAIL = undef;
		my $LIKESPAM = undef;
		my $PASSWORD = undef;
		my $FULLNAME = undef;
		my $SCHEDULE = undef;
		my @DATA = &ZCSV::parse_csv($line);
		my $REWARD_UPDATE = undef;
		my $REWARD_NOTE = undef;

		print STDERR Dumper(\@DATA);

		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {	
			print "<div>$destfield = $DATA[$pos]<br></div>\n";
			if ($destfield eq '') {
				# SKIP blank dest fields
				}
			elsif (substr($destfield,0,1) eq '%') {
				if ($destfield eq '%EMAIL') { 
					$EMAIL = $DATA[$pos]; 
					}
				elsif ($destfield eq '%LIKESPAM') { $LIKESPAM = $DATA[$pos]; }
				elsif ($destfield eq '%NEWSLETTER') { $LIKESPAM = $DATA[$pos]; }
				elsif ($destfield eq '%REWARD_UPDATE') { $REWARD_UPDATE = $DATA[$pos]; }	# can be =,+,-
				elsif ($destfield eq '%REWARD_NOTE') {  $REWARD_NOTE = $DATA[$pos]; }	# a note that goes with REWARD_UPDATE 
				elsif ($destfield eq '%PASSWORD') { 
					$PASSWORD = $DATA[$pos]; 
					if ($PASSWORD eq '*') { $PASSWORD = &ZTOOLKIT::make_password(); }
					}
				elsif ($destfield eq '%FULLNAME') { $FULLNAME = $DATA[$pos]; }
				elsif ($destfield eq '%SCHEDULE') { $SCHEDULE = $DATA[$pos]; }
				} 
			elsif ($destfield =~ /^bill_/) { $billhash{$destfield} = $DATA[$pos]; }
			elsif ($destfield =~ /^ship_/) { $shiphash{$destfield} = $DATA[$pos]; }
			else { $metahash{$destfield} = $DATA[$pos]; }
			$pos++;  # move to the next field that we should parse
			}

		$bj->progress($rows_done++,$rows_count,"Customer: $EMAIL");

		## now lets do some sanity
		# add the customer record here
		if (defined($EMAIL) && ZTOOLKIT::validate_email($EMAIL)) { 
			my ($C) = CUSTOMER->new($USERNAME,'EMAIL'=>$EMAIL,PRT=>$PRT,'INIT'=>1+2+4+8);

			if (scalar(keys %billhash)>0) { 
				my ($billaddr) = CUSTOMER::ADDRESS->new($C,'BILL',{})->from_legacy(\%billhash);
				$C->add_address($billaddr); 
				}
			if (scalar(keys %shiphash)>0) { 
				my ($shipaddr) = CUSTOMER::ADDRESS->new($C,'SHIP',{})->from_legacy(\%shiphash);
				$C->add_address('SHIP',\%shiphash); 
				}

			if (defined $LIKESPAM) {
				if (defined $optionsref->{'OVERRIDE'}) {
					$C->set_attrib('INFO.NEWSLETTER',$LIKESPAM);
					print STDERR "OVERRIDE $FULLNAME $LIKESPAM \n";					
					}
				elsif (not defined $C->fetch_attrib('INFO.CREATED_GMT') || 
						 $C->fetch_attrib('INFO.CREATED_GMT')>(time()-(86400*14))) {
					$C->set_attrib('INFO.NEWSLETTER',$LIKESPAM); 
					#print STDERR "NOT TOO OLD $FULLNAME $LIKESPAM \n";					
					}
				}
			if (defined $REWARD_UPDATE) { 
				if (not defined $REWARD_NOTE) { $REWARD_NOTE = 'CSV Import'; }
				$C->update_reward_balance($REWARD_UPDATE,$REWARD_NOTE);
				}
			if (defined $PASSWORD) { $C->set_attrib('INFO.PASSWORD',$PASSWORD); }
			if (defined $FULLNAME) { $C->set_attrib('INFO.FULLNAME',$FULLNAME); }
			# if (defined $SCHEDULE) { $C->set_attrib('INFO.SCHEDULE',$SCHEDULE); }
			$C->save();
			if (scalar(keys %metahash)>0) { &CUSTOMER::save_meta_from_hash($USERNAME,$EMAIL,\%metahash); }

			$bj->slog("Adding Customer $EMAIL");
			}
		else {
			$bj->slog("Invalid email address (<font color=red>$EMAIL</font>) : Customer <font color=blue>$FULLNAME</font> not imported");
			}
		}
	}


1;
