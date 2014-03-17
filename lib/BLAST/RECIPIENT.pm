package BLAST::RECIPIENT;

use strict;

sub bcc { return(undef); }
sub blaster { return(@_[0]->{'*BLASTER'}); }
sub username { return(@_[0]->{'*BLASTER'}->username()); }
sub meta { return(@_[0]->{'%META'} || {}); }

1;
