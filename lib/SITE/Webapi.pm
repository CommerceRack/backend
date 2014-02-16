package SITE::Webapi;

use locale;
use POSIX qw(locale_h);
use CGI;
use utf8;
use Encode;

sub responseHandler {
	my ($r) = shift;

	use locale;
	
	my $oldlocale = setlocale("LC_CTYPE");
	# use encoding 'utf8';

	setlocale("LC_CTYPE","en_US");
   setlocale("LC_CTYPE","sv_SE");

#	CGI::autoEscape(undef);
#	use encoding 'utf8';
   my $cgi = new CGI;
#	CGI::autoEscape(undef);
#	$cgi->charset("");

	my $x = $cgi->param('x');
#	$x = decode("iso-8859-1", $x); = "zX\x{c3}\x{a5}\x{c3}\x{b6}\x{c3}\x{a4}\x{c3}\x{a4}\x{c3}\x{b6}\x{c3}\x{a4}";
#	$x = decode("utf8", $x); 			"zX\x{e5}\x{f6}\x{e4}\x{e4}\x{f6}\x{e4}";

	if (utf8::is_utf8($x)) {
		$x = decode("utf8", $x);
		utf8::decode($x);
		}

	print STDERR Dumper($x);
#	$x = encode("utf8", $x);

	# $x = encode("utf8", $x);


	

# 	utf8::upgrade($x); = "zX\x{c3}\x{a5}\x{c3}\x{b6}\x{c3}\x{a4}\x{c3}\x{a4}\x{c3}\x{b6}\x{c3}\x{a4}";
#	utf8::downgrade($x); = zXåöääöä

#	 $x = Encode::decode("iso-8859-1", $x);
#	$x = Encode::encode("utf8", $x);
#
#	 $x = Encode::decode("iso-8859-1", $x);
#	$x = Encode::decode($x);

	# from_to($x, "iso-8859-1", "cp1250");

   use Data::Dumper;
#   print STDERR Dumper($cgi);

	# utf8::encode($x);
	
	$r->content_type("text/html");
	$r->print(q~
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
</head>
<body>
~);

	$r->print("test<pre>");
	$r->print(Dumper($oldlocale,$cgi,$x,utf8::is_utf8($x),Dumper(\%ENV)));
	$r->print("</pre>");
	$r->print(qq~
$old_locale
<form action="">
<input type="textbox" value="$x" name="x">
<input type="submit">
</form>

~);

	return(Apache2::Const::OK);
	}

1;