package SITE::Test;

use Apache2::RequestRec (); # for $r->content_type
use Apache2::ServerRec ();
use Apache2::RequestIO ();  # for print
use Apache2::Const -compile => ':common';

sub runthis {
	my $r = shift;

	return(Apache2::Const::OK);
	}


1;
