package BOSSTOOLS;

use strict;

use lib "/backend/lib";
require ZOOVY;
require DBINFO;
require strict;



sub isLoginValid {
	my ($USERNAME,$LOGIN) = @_;

	my $ERROR = undef;
	if ($LOGIN eq '') { 	$ERROR = 'Username is blank!'; }
	if ($LOGIN =~ /^support/) { $ERROR = 'Usernames containing the word "support" are not valid, please choose a different name.'; }
	if ($LOGIN =~ /^admin$/) { $ERROR = 'Username "admin" is not valid, please choose a different name.'; }
	if ($LOGIN =~ /^zoovy/) { $ERROR = 'Usernames containing the word "zoovy" are not valid, please choose a different name.'; }
	if ($LOGIN =~ /^boss/) { $ERROR = 'Username containing the word "boss" are not valid, please choose a different name.' };
	# if (($UREF->{'CREATED_GMT'}>0) && (length($LOGIN)<3)) { $ERROR = 'Usernames must have at least 3 characters'; }
	
	if ($LOGIN =~ /[^\w]/) { $ERROR = 'Username contains invalid characters (allowed: A-Z 0-9)'; }
	if ($LOGIN =~ /^[0-9]+/) { $ERROR = 'Username may not start with a number'; }
	if ($LOGIN eq 'grant') { $ERROR = 'Username "grant" conflicts with SQL reserved word. '; }

	return($ERROR);
	};
	





1;

__DATA__
