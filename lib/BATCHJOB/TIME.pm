package BATCH::TIME;

$BATCH::CODEREF->{'TIME'} = sub {
	my ($b) = @_;
	my $i = 100;
	while ( $i-- > 0 ) {
		my $msg = "time is now: ".time()." $i";
		warn $msg."\n";
		$b->update('MSG'=>$msg,TOTAL=>100,COUNT=>100-$i);
		sleep(1);
		}
	};

1;

