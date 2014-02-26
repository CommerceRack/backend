package BATCHJOB::EXPORT::PAGES;

use lib "/backend/lib";
use PAGE;
use NAVCAT;
use JSON::XS;

sub generate {
	my ($bj) = @_;

	my $USERNAME = $bj->username();

	my %PAGES = ();
	my ($NC) = NAVCAT->new($bj->username(),'PRT'=>$bj->prt());
	foreach my $path ( ".", $NC->paths() ) {
		print "PATH:$path\n";
		$PAGES{$path} = {};
		my ($PG) = PAGE->new($bj->username(),$path,'PRT'=>$bj->prt());
		foreach my $a ($PG->attribs()) {
			next if (substr($a,0,1) eq '_');
			next if ($a eq 'fl');
			$PAGES{ $path }->{$a} = $PG->get($a);
			}		
		}
	
	my $TMPFILEPATH = sprintf("%s/job%d-%s-CSV+%s.csv",&ZOOVY::tmpfs(), $bj->id(),$bj->username(),$bj->guid());
	my $coder = JSON::XS->new->utf8->pretty->allow_nonref;

	open F, ">$TMPFILEPATH";
	print F $coder->encode(\%PAGES);
	close F;

	return($TMPFILEPATH);
	}



1;