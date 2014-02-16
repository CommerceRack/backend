
use lib "/httpd/modules";
use DOMAIN::REGISTER;

if (not defined $USERNAME) {
  print "No USERNAME\n";
  die();
  }

my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
my ($R1USER,$R1PASS) = DOMAIN::REGISTER::credentials($USERNAME);

open F, ">$USERPATH/resellone.txt";
print F "username: $R1USER\n";
print F "password: $R1PASS\n";
close F;
