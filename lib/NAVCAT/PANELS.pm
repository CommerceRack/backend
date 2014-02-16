package NAVCAT::PANELS;

use strict;
use lib "/backend/lib";
require NAVCAT;
require LUSER;

## 
## <script type="text/javascript" src="/biz/ajax/navcat.js"></script>
##
sub buildTree {
	my ($NC, $root, %options) = @_;

	my $html = '<table border=0>';
	my $PID = uc($options{'product'});
	foreach my $safe (sort $NC->paths($root)) {
		next if (substr($safe,0,1) eq '$');
		$html .= "<tr><td nowrap>";
		my ($pretty,$children,$products) = $NC->get($safe);
		my $checked = (index(",$products,",",$PID,")>=0)?'checked':'';

		if ($safe eq '.') { 
			$pretty = 'Homepage';
			}
		elsif (substr($safe,0,1) eq '*') {
			## system page.
			}
		else {
			# adds indentation.
			my $len = $safe;
			$len =~ s/[^\.]+//gs; 
			foreach (1..length($len)) { $html .= " &nbsp;&nbsp;&nbsp;&nbsp;"; }
			}
		$html .= qq~<input type="checkbox" $checked name="PATH=$safe"> $pretty<br>~;
		$html .= "</td></tr>";
		}
	
	my $lists = '';
	foreach my $safe (sort $NC->paths($root)) {
		next unless (substr($safe,0,1) eq '$');
		my ($pretty,$children,$products) = $NC->get($safe);
		my $checked = (index(",$products,",",$PID,")>=0)?'checked':'';
		$lists .= qq~<tr><td><input type="checkbox" $checked name="PATH=$safe"> LIST: $pretty</td></tr>~;
		}
	if ($lists ne '') {
		$html .= "<tr><td>&nbsp;</td></tr>$lists";
		}

	$html .= "</table>";
	return($html);
	}


1;