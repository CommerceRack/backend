package ORDER::ASCX12;


# http://www.x12.org
# http://www.hmco.com/pdf/HM_4010_850_OUT.pdf

# www.edidev.com/UsefulEDI.htm


##
## take an x12 order and parse it into lines
##
sub parse {
	my ($data,$delim,$eol) = @_;

	if (not defined $delim) { $delim = '*'; }
	if (not defined $eol) { $eol = '~'; }

	my @lines = ();
	foreach my $rawline (split(/$eol/,$data)) {
		push @lines, $rawline;
		$rawline =~ s/[\n\r]+$//gs;	# remove trailing cr/lf (if any) from data
		$rawline =~ s/^[\n\r]+//gs;	# remove leading cr/lf (if any) from data
		}
	return(\@lines);
	}


# perl -e 'use lib "/backend/lib"; use ORDER::ASCX12; ORDER::ASCX12::test()';
sub test {
	$/ = undef; my ($data) = <DATA>; $/ = "\n";
	use Data::Dumper;
	print Dumper(&ORDER::ASCX12::parse($data));
	}

1;

__DATA__
ISA*00* *00* *12*XXXXXXXXXXX *01*098533326*100107*0735*U*00400*000008105*0*P*|~
GS*PO*XXXXXXXXXXX*098533326*100107*0735*9071*X*004010~
# 010 ST Transaction Set Header M 1 Must use 9
ST*850*24784~

# 
BEG*00*NE*CH2372853**100105~
CUR*BY*USD~
TAX*478231*1~
FOB*PC*OR*SHIP PER ROUTING GUIDE~
ITD*01*3*1*20100115*15*20100115*30*****Net 30~
TD5*B****See Routing Guide~
N9*ZZ*Note~
MSG*PO Note goes here~
N1*ST**92*BLT~
N3*980 LUNT AVENUE* Bldg 2~
N4*BALTIMORE VILLAGE*MD*65437*US~
PER*BD*ROBERT SMITHSON*TE*612-894-3206~
PO1*0001*800*EA*160**BP*ST3146356SS~
PID*X***2TB INTERNAL KIT 5900.11 SATA INT 5900 RPM 32MB 3.5IN~
SCH*4*EA***010*091217~
N9*ZZ*Note~
MSG*PO Note goes here~
CTT*1~
SE*19*20~
GE*1*24784~
IEA*1*000008105~
