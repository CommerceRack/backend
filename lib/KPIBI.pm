package KPIBI;

use Data::Dumper;
use strict;
use POSIX;
use DateTime;
use URI::Escape::XS;
use Date::Calc;
use Text::Soundex;
use YAML::Syck;
use lib "/backend/lib";
require ZTOOLKIT;
require ZOOVY;

$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;      # do not fucking enable this. it has issues with cr/lf 183535

$KPIBI::SRANDED = 0;

#
# DSN parameters:
#	ctype	:	$ (format dollars)	# (format number)
#	fmt	:	avg,sum,min,max
#	fm 	:	formula (for when the id type is 'FORMULA')
#	c		:	1,2,3 	(which column of data to use)
#	t		: 	title of the graph


#
# GRP is the group type of stat, table below:
# GRPOPT is reserved for future use (e.x.: but allows us to further drill down GRP)
# -------------------------------------
# =	OGMS	Overall Sales
# =	OWEB  Overall web based sources
# =	OWEBC	Overall web Multivariant C (other not a/b or blank)
# =	ORPT	Overall Repeat Customer sales
# =	OEXP 	Overall Expedited Shipping
# =	OINT 	Overall International
#		
# =PRT	PRT%02X	partition
# =PRA	PRT%02X	partition - A side
# =PRB	PRT%02X	partition - B side
# =PRC	PRT%02X	partition - C side
# =PIS	PIS%02X	product is bit (see @ZOOVY::PROD_IS)
# ~D	Dxxxx	domain ~soundex map
# ~M	Mxxxx	manufacturer ~soundex map
# ~Q	Qxxxx	supplier ~soundex map
# Sxxx : if it starts with an "S" then it's a SDST (syndication destination)
# $A  Axxxx affiliate (meta) lookup
# $C	Cxxxx	coupon lookup (coupon code is stored in $pretty)
# $W	Wxxxx schedule lookup (schedule code is stored in $pretty)
# 
# -- reserved --
# R???? : reserved for return metrics

%KPIBI::SIZES = (
	'1x025'=>{ title=>'25% (wide) x 1 (high)', style=>'height: 205px; width: 25%;', },
	'1x033'=>{ title=>'33% (wide) x 1 (high)', style=>'height: 205px; width: 33%;', },
	'1x050'=>{ title=>'50% (wide) x 1 (high)', style=>'height: 205px; width: 50%;', },
	'1x064'=>{ title=>'66% (wide) x 1 (high)', style=>'height: 205px; width: 64%;', },
	'1x075'=>{ title=>'75% (wide) x 1 (high)', style=>'height: 205px; width: 75%;', },
	'1x100'=>{ title=>'100% (wide) x 1 (high)', style=>'height: 205px; width: 100%', },
	'2x025'=>{ title=>'25% (wide) x 2 (high)', style=>'height: 410px; width: 25%;', },
	'2x033'=>{ title=>'33% (wide) x 2 (high)', style=>'height: 410px; width: 33%;', },
	'2x050'=>{ title=>'50% (wide) x 2 (high)', style=>'height: 410px; width: 50%;', },
	'2x064'=>{ title=>'66% (wide) x 2 (high)', style=>'height: 410px; width: 64%;', },
	'2x075'=>{ title=>'75% (wide) x 2 (high)', style=>'height: 410px; width: 75%;', },
	'2x100'=>{ title=>'100% (wide) x 2 (high)', style=>'height: 410px; width: 100%', },
	'3x025'=>{ title=>'25% (wide) x 3 (high)', style=>'height: 615px; width: 25%;', },
	'3x033'=>{ title=>'33% (wide) x 3 (high)', style=>'height: 615px; width: 33%;', },
	'3x050'=>{ title=>'50% (wide) x 3 (high)', style=>'height: 615px; width: 50%;', },
	'3x064'=>{ title=>'66% (wide) x 3 (high)', style=>'height: 615px; width: 64%;', },
	'3x075'=>{ title=>'75% (wide) x 3 (high)', style=>'height: 615px; width: 75%;', },
	'3x100'=>{ title=>'100% (wide) x 3 (high)', style=>'height: 615px; width: 100%', },
#	'1x025'=>{ title=>'200px (wide) x 1 (high)', style=>'height: 205px; width: 200px;', width=>200 },
#	'1x033'=>{ title=>'266px (wide) x 1 (high)', style=>'height: 205px; width: 266px;', width=>266 },
#	'1x050'=>{ title=>'400px (wide) x 1 (high)', style=>'height: 205px; width: 400px;', width=>400 },
#	'1x064'=>{ title=>'532px (wide) x 1 (high)', style=>'height: 205px; width: 532px;', width=>532 },
#	'1x075'=>{ title=>'600px (wide) x 1 (high)', style=>'height: 205px; width: 600px;', width=>600 },
#	'1x100'=>{ title=>'800px (wide) x 1 (high)', style=>'height: 205px; width: 800px', width=>800 },
#	'2x025'=>{ title=>'200px (wide) x 2 (high)', style=>'height: 410px; width: 200px;', width=>200 },
#	'2x033'=>{ title=>'266px (wide) x 2 (high)', style=>'height: 410px; width: 266px;', width=>266 },
#	'2x050'=>{ title=>'400px (wide) x 2 (high)', style=>'height: 410px; width: 400px;', width=>400 },
#	'2x064'=>{ title=>'532px (wide) x 2 (high)', style=>'height: 410px; width: 532px;', width=>532 },
#	'2x075'=>{ title=>'600px (wide) x 2 (high)', style=>'height: 410px; width: 600px;', width=>600 },
#	'2x100'=>{ title=>'800px (wide) x 2 (high)', style=>'height: 410px; width: 800px', width=>800 },
#	'3x025'=>{ title=>'200px (wide) x 3 (high)', style=>'height: 615px; width: 200px;', width=>200 },
#	'3x033'=>{ title=>'266px (wide) x 3 (high)', style=>'height: 615px; width: 266px;', width=>266 },
#	'3x050'=>{ title=>'400px (wide) x 3 (high)', style=>'height: 615px; width: 400px;', width=>400 },
#	'3x064'=>{ title=>'532px (wide) x 3 (high)', style=>'height: 615px; width: 532px;', width=>532 },
#	'3x075'=>{ title=>'600px (wide) x 3 (high)', style=>'height: 615px; width: 600px;', width=>600 },
#	'3x100'=>{ title=>'800px (wide) x 3 (high)', style=>'height: 615px; width: 800px', width=>800 },
	);


@KPIBI::DATA_FORMATTING = (
	[ 'sum'=>'Sum' ],
	[ 'avg'=>'Avg Value' ],
	[ 'min'=>'Min Value' ],
	[ 'max'=>'Max Value' ],
	);


## table of months for summarization
## column 0: month name
## column 1: days in a normal year
## column 2: days in a leap year
## column 3: last julian day of month (non leap year)
## column 4: last julian day of month (leap year)
@KPIBI::MONTHS = (
	[ 'Jan', 31, 31, 31, 31 ],
	[ 'Feb', 28, 29, 59, 60 ],
	[ 'Mar', 31, 31, 90, 91 ],
	[ 'Apr', 30, 30, 120, 121 ],
	[ 'May', 31, 31, 151, 152 ],
	[ 'Jun', 30, 30, 181, 182 ],
	[ 'Jul', 31, 31, 212, 213 ],
	[ 'Aug', 31, 31, 243, 244 ],
	[ 'Sep', 30, 30, 273, 274 ],
	[ 'Oct', 31, 31, 304, 305 ],
	[ 'Nov', 30, 30, 334, 335 ],
	[ 'Dec', 31, 31, 365, 366 ]
	);

@KPIBI::DAYS = (
	[ 'Mon' ],
	[ 'Tues' ],
	[ 'Wed' ],
	[ 'Thurs' ],
	[ 'Fri' ],
	[ 'Sat' ],
	[ 'Sun' ],
	);

@KPIBI::QUARTERS = (
	[ 'Q1', 90, 91 ],
	[ 'Q2', 181, 182],
	[ 'Q3', 273, 274 ],
	[ 'Q4', 365, 366 ]
	);

@KPIBI::GRAPHS = (
	# line, spline, area, areaspline, scatter	
	{ id=>'area', title=>'Area',  },
	{ id=>'area.stacked', title=>'Area - Stacked',  },
	{ id=>'area.percent', title=>'Area - Stacked Percentage',  },
	{ id=>'bar', title=>'Horizontal Bar Graph',  },
	{ id=>'bar.stacked', title=>'Horizontal Bar Graph - Stacked',  },
	{ id=>'bar.percent', title=>'Horizontal Bar Graph - Stacked Percentage',  },
	{ id=>'column', title=>'Vertical Column Graph',  },
	{ id=>'column.stacked', title=>'Vertical Column Graph - Stacked',  },
	{ id=>'column.percent', title=>'Vertical Column Graph - Stacked Percentage',  },
	{ id=>'areaspline', title=>'Area Spline',  },
	{ id=>'line', title=>'Line Graph',  },
#	{ id=>'scatter', title=>'Scatter Graph',  },
	{ id=>'pie', title=>'Pie Chart',  },
#	{ id=>'donut', title=>'Donut Chart',  },
	);

@KPIBI::PERIODS = (
	[ 'months.1', 'This Month + 1 Prior Months' ],
	[ 'months.2', 'This Month + 2 Prior Months' ],
	[ 'months.3', 'This Month + 3 Prior Months' ],
	[ 'weeks.1', 'This Week + 1 Prior Weeks' ],
	[ 'weeks.2', 'This Week + 2 Prior Weeks' ],
	[ 'weeks.3', 'This Week + 3 Prior Weeks' ],
	[ 'weeks.4', 'This Week + 4 Prior Weeks' ],
	[ 'weeks.5', 'This Week + 5 Prior Weeks' ],
	[ 'weeks.6', 'This Week + 6 Prior Weeks' ],
	[ 'weeks.7', 'This Week + 7 Prior Weeks' ],
	[ 'weeks.8', 'This Week + 8 Prior Weeks' ],
	[ 'day.today', 'Today', ],
	[ 'day.yesterday', 'Yesterday', ],
	[ 'days.7', 'Last 7 Days',  ],
	[ 'days.10', 'Last 10 Days', ],
	[ 'days.14', 'Last 14 Days', ],
	[ 'days.21', 'Last 21 Days', ],
	[ 'days.28', 'Last 28 Days', ],
	[ 'days.90', 'Last 90 Days',  ],
	[ 'quarter.this', 'This Quarter',  ],
	[ 'quarter.tly', 'This Quarter Last Year', ],
	[ 'quarter.last', 'Last Quarter',  ],
	[ 'month.this', 'This Month' ],
	[ 'month.tly', 'This Month Last Year' ],
	[ 'month.last', 'Last Month' ],
	[ 'week.this', 'This Week' ],
	[ 'week.tly', 'This Week Last Year' ],
	[ 'week.last', 'Last Week' ],
	[ 'ytd.this', 'Year-To-Date' ],
	[ 'ytd.last', 'Last Year' ],
	);

@KPIBI::GRPBY = (
	[ 'none', 'None (Merge Datasets)' ],
	[ 'day', 'Date: Day (Full Detail)' ],
	[ 'week', 'Date: Week' ],
	[ 'month', 'Date: Month' ],
	[ 'quarter', 'Date: Quarter' ],
	[ 'dow', 'Date: Day of Week' ],
	);

@KPIBI::DATASETS = (
	[ 'null?c=0&ctype=#', 'None' ],
	[ 'random?c=1&ctype=#', 'Random Numbers (testing)'],
	[ 'OGMS?c=1&ctype=$', 'All Orders (GMS $)' ],
	[ 'OGMS?c=2&ctype=#', 'All Orders (# Orders)' ],
	[ 'OGMS?c=3&ctype=#', 'All Orders (# Units Sold)' ],
	[ 'OWEB?c=1&ctype=$', 'All Website Orders (GMS $)' ],
	[ 'OWEB?c=2&ctype=#', 'All Website Orders (# Orders)' ],
	[ 'OWEB?c=3&ctype=#', 'All Website Orders (# Units Sold)' ],
	[ 'FORMULA?c=1&ctype=$&fm=OGMS-OWEB', 'Non Website Orders (GMS $)', "OGMS,OWEB" ],
	[ 'FORMULA?c=2&ctype=#&fm=OGMS-OWEB', 'Non Website Orders (# Orders)', "OGMS,OWEB" ],
	[ 'FORMULA?c=3&ctype=#&fm=OGMS-OWEB', 'Non Website Orders (# Units Sold)', "OGMS,OWEB" ],
	[ 'ORPT?c=1&ctype=$', 'Repeat Customers (GMS $)' ],
	[ 'ORPT?c=2&ctype=#', 'Repeat Customers (# Orders)' ],
	[ 'ORPT?c=3&ctype=#', 'Repeat Customers (# Units Sold)' ],
	[ 'FORMULA?c=1&ctype=$&fm=OGMS-ORPT', 'New Customers (GMS $)', "OGMS,ORPT" ],
	[ 'FORMULA?c=2&ctype=#&fm=OGMS-ORPT', 'New Customers (# Orders)', "OGMS,ORPT" ],
	[ 'FORMULA?c=3&ctype=#&fm=OGMS-ORPT', 'New Customers (# Units Sold)', "OGMS,ORPT" ],
	[ 'OEXP?c=1&ctype=$', 'Expedited Shipping (GMS $)' ],
	[ 'OEXP?c=2&ctype=#', 'Expedited Shipping (# Orders)' ],
	[ 'OEXP?c=3&ctype=#', 'Expedited Shipping (# Units SOld)' ],
	[ 'FORMULA?c=1&ctype=$&fm=OGMS-OEXP', 'Standard Shipping (GMS $)', "OGMS,OEXP" ],
	[ 'FORMULA?c=2&ctype=#&fm=OGMS-OEXP', 'Standard Shipping (# Orders)', "OGMS,OEXP" ],
	[ 'FORMULA?c=3&ctype=#&fm=OGMS-OEXP', 'Standard Shipping (# Units SOld)',"OGMS,OEXP" ],
	[ 'OINT?c=1&ctype=$', 'International Orders (GMS $)' ],
	[ 'OINT?c=2&ctype=#', 'International Orders (# Orders)' ],
	[ 'OINT?c=3&ctype=#', 'International Orders (# Units Sold)' ],
	[ 'FORMULA?c=1&ctype=$&fm=OGMS-OINT', 'Domestic Orders (GMS $)', "OGMS,OINT" ],
	[ 'FORMULA?c=2&ctype=#&fm=OGMS-OINT', 'Domestic Orders (# Orders)', "OGMS,OINT" ],
	[ 'FORMULA?c=3&ctype=#&fm=OGMS-OINT', 'Domestic Orders (# Units Sold)', "OGMS,OINT" ],
	[ 'OGFT?c=1&ctype=$', 'Gift Orders (GMS $)' ],
	[ 'OGFT?c=2&ctype=#', 'Gift Orders (# Orders)' ],
	[ 'OGFT?c=3&ctype=#', 'Gift Orders (# Units Sold)' ],
	[ 'FORMULA?c=1&ctype=$&fm=OGMS-OGFT', 'Non-Gift Orders (GMS $)', "OGMS,OGFT" ],
	[ 'FORMULA?c=2&ctype=#&fm=OGMS-OGFT', 'Non-Gift Orders (# Orders)', "OGMS,OGFT" ],
	[ 'FORMULA?c=3&ctype=#&fm=OGMS-OGFT', 'Non-Gift Orders (# Units Sold)', "OGMS,OGFT" ],

	# perl -e 'use lib "/backend/lib"; use URI::XS::Escape; print URI::Escape::XS::uri_escape("+");'
	# NOTE: + must be encoded as %2B
	);




@KPIBI::DYNDATASETS = (
	[ '', 'None' ],
	[ 'PRTS?c=1&ctype=$', 'Sales by Partitions (GMS)' ],
	[ 'PRTS?c=2&ctype=#', 'Sales by Partitions (# Orders)' ],
	[ 'PRTS?c=3&ctype=#', 'Sales by Partitions (# Units Sold)' ],
	[ 'SCHEDULES?c=1&ctype=$', 'Sales by Schedules (GMS)' ],
	[ 'SCHEDULES?c=2&ctype=#', 'Sales by Schedules (# Orders)' ],
	[ 'SCHEUDLES?c=3&ctype=#', 'Sales by Schedules (# Units Sold)' ],
	[ 'DOMAINS?c=1&ctype=$', 'Sales by Domains (GMS)' ],
	[ 'DOMAINS?c=2&ctype=#', 'Sales by Domains (# Orders)' ],
	[ 'DOMAINS?c=3&ctype=#', 'Sales by Domains (# Units Sold)' ],
	[ 'TAGS?c=1&ctype=$', 'Sales by Tags (GMS)' ],
	[ 'TAGS?c=2&ctype=#', 'Sales by Tags (# Orders)' ],
	[ 'TAGS?c=3&ctype=#', 'Sales by Tags (# Units Sold)' ],
	[ 'MARKETS?c=1&ctype=$', 'Sales by Integrations (GMS)' ],
	[ 'MARKETS?c=2&ctype=#', 'Sales by Integrations (# Orders)' ],
	[ 'MARKETS?c=3&ctype=#', 'Sales by Integrations (# Units Sold)' ],
	);


@KPIBI::DYNDATASETS2 = (
	[ '', 'None' ],
	[ 'PRTS', 'Sales by Partitions' ],
	[ 'SCHEDULES', 'Sales by Schedules' ],
	[ 'DOMAINS', 'Sales by Domains' ],
	[ 'TAGS', 'Sales by Tags' ],
	[ 'MARKETS', 'Sales by Integrations' ],
	);


##
## this is a drop in replacement for ORDER::STATS (which can probably be deprecated/removed at this point)
##	TYPE is probably 'OGMS' but could be a lot of things.
##
# perl -e 'use lib "/backend/lib"; use Data::Dumper; use KPIBI; print Dumper(KPIBI::quick_stats("toynk","OGMS"));'
sub quick_stats {
	my ($USERNAME,$GRP) = @_;

	my ($KPI) = KPIBI->new($USERNAME,undef);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $qtGRP = $udbh->quote($GRP);
	my $pstmt = sprintf("select STAT_GMS,STAT_INC,STAT_UNITS from %s where MID=%d /* %s */ and DT=%d and GRP=%s",$KPI->tb(),$KPI->mid(),$KPI->username(),KPIBI::ts_to_dt(time()),$qtGRP);
	my ($GMS,$INC,$UNITS) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return($GMS/100,$INC,$UNITS);
	}


## cheesy, but fast leapyear function that will work for the next 1,000 years (until 3,000)
## perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::is_dt_leap("12001");'
sub is_dt_leap {
	my ($dt) = @_;
	if (substr($dt,0,2) % 4) { return 0; }
	return(1);
	}

## perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::dt_to_week("12100");'
sub dt_to_week {
	my ($dt) = @_;
	my ($day) = substr($dt,2,3);
	
	return(sprintf("Wk%d",int($day / 7)+1));
	}

## 
## perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::dt_to_month("12100");'
##
sub dt_to_month {
	my ($dt) = @_;

	my $day = int(substr($dt,2,3));
	my $is_leap = &KPIBI::is_dt_leap($dt);

	my $month = undef;
	foreach my $m (@KPIBI::MONTHS) {
		next if ($month);
		if ($m->[ 3+$is_leap ] >= $day) { $month = $m->[0]; }
  		# print sprintf("%d >= %d $month\n",$m->[ 3+$is_leap ],$day);
		}

	return($month);
	}


##
# perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::dt_to_quarter("12008");'
sub dt_to_quarter {
	my ($dt) = @_;
	my $day = int(substr($dt,2,3));
	my $is_leap = &KPIBI::is_dt_leap($dt);

	my $qtr = '';
	foreach my $q (@KPIBI::QUARTERS) {
		next if ($qtr ne '');
		if ($q->[ 1+$is_leap ] >= $day) { $qtr = $q->[0]; }
  		# print sprintf("%d <= %d [%s]\n",$q->[ 1+$is_leap ],$day,$qtr);
		}
	if (defined $qtr) { $qtr = sprintf("%s-%d",$qtr,2000+substr($dt,0,2)); }
	return($qtr);
	}


##
## perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::dt_to_day("12032");'
##
sub dt_to_day {
	my ($dt) = @_;
	
	my $day = int(substr($dt,2,3));
	my $is_leap = &KPIBI::is_dt_leap($dt);

	my $response = undef;
	foreach my $m (@KPIBI::MONTHS) {
		next if ($response);
		if ($m->[ 1+$is_leap ] >= $day) {
			$response = sprintf("%s-%s",$m->[0],$day);
			}
		else {
			$day = $day - ($m->[ 1+$is_leap ]);
			}
		}
	return($response);
	}


## 
##
##
sub dt_to_dow {
	my ($dt) = @_;

	my $yyyymmdd = &KPIBI::dt_to_yyyymmdd($dt);	
	my ($yyyy) = substr($yyyymmdd,0,4);
	my ($mm) = substr($yyyymmdd,4,2);
	my ($dd) = substr($yyyymmdd,6,2);

	my $dto = DateTime->new(
      year       => $yyyy,
      month      => $mm,
      day        => $dd,
      time_zone  => $::LocalTZ
		);

	my $result = sprintf("%s",$KPIBI::DAYS[ $dto->dow() - 1 ]->[0]);
	return($result);
	}


sub user_collections_by_id {
	my ($self) = @_;
	my %ref = ();
	foreach my $x (@{$self->user_collections()}) {
		$ref{$x->{'ID'}} = $x->{'TITLE'};
		}
	return(\%ref);
	}

##
## returns an arrayref of collections
##
sub user_collections {
	my ($self) = @_;

	my @ar = ();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my $pstmt = "select UUID,TITLE,CREATED_TS,MODIFIED_TS,VERSION,PRIORITY from KPI_USER_COLLECTIONS where MID=$MID order by ID";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($UUID,$TITLE,$CREATED,$MODIFIED,$VERSION,$PRIORITY) = $sth->fetchrow() ) {
		push @ar, { UUID=>$UUID, TITLE=>$TITLE, CREATED=>$CREATED, MODIFIED=>$MODIFIED, VERSION=>$VERSION, PRIORITY=>$PRIORITY };
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@ar);
	}


sub collection_detail {
	my ($self, $UUID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my $pstmt = "select ID,TITLE,CREATED_TS,MODIFIED_TS,VERSION,PRIORITY,YAML from KPI_USER_COLLECTIONS where MID=$MID and UUID=".$udbh->quote($UUID);
	my ($R) = $udbh->selectrow_hashref($pstmt);
	&DBINFO::db_user_close();

	if (defined $R) {
		if ($R->{'YAML'} ne '') { 
			$R->{'@GRAPHS'} = YAML::Syck::Load($R->{'YAML'});
			}
		delete $R->{'YAML'};
		}
	return($R);
	}


sub create_collection {
	my ($self, %params) = @_;

	my %db = ();
	$db{'MID'} = $self->mid();
	$db{'PRT'} = $self->prt();
	$db{'UUID'} = $params{'UUID'};
	if ($params{'TITLE'}) { $db{'TITLE'} = $params{'TITLE'}; }
	$db{'VERSION'} = $params{'VERSION'};
	if ($params{'PRIORITY'}) { $db{'PRIORITY'} = $params{'PRIORITY'}; }
	$db{'YAML'} = $params{'YAML'};
	$db{'*MODIFIED_TS'} = 'now()';

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = &DBINFO::insert($udbh,'KPI_USER_COLLECTIONS',\%db,sql=>1,key=>['MID','UUID'],on_insert=>{ '*CREATED_TS'=>'now()' } );
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	my ($ID) = &DBINFO::last_insert_id($udbh);
	&DBINFO::db_user_close();
	return($ID);
	}

sub nuke_collection {
	my ($self, $UUID) = @_;

	my ($MID) = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from KPI_USER_COLLECTIONS where MID=$MID and UUID=".$udbh->quote($UUID);
	print STDERR $pstmt."\n";
	my $count = int($udbh->do($pstmt));
	&DBINFO::db_user_close();
	return($count);

	}


##
## dynamic datasets are used when the number of rows is not known until the report is run.
##
sub dynamic_datasets {
	my ($self,$DDSET) = @_;
	
	my $USERNAME = $self->username();
	my @RESULTS = ();

	## DDSET will be something like: PRTS?c=2
	my ($ddsetid,$ddparams) = split(/\?/,$DDSET,2);
	my $params = &ZTOOLKIT::parseparams($ddparams);
	my $style = '???';
	if ($params->{'c'} == 1) { $style = 'GMS $'; }
	if ($params->{'c'} == 2) { $style = '# Orders'; }
	if ($params->{'c'} == 3) { $style = '# Units Sold'; }

	if ($ddsetid eq 'PRTS') {
		require ZWEBSITE;
		foreach my $prt (@{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
			push @RESULTS, [ sprintf("PRT%02X?$ddparams",$prt), "Partition $prt ($style)" ];
			}
		}
	elsif ($ddsetid eq 'SCHEDULES') {
		require WHOLESALE;
		foreach my $S (@{WHOLESALE::list_schedules($USERNAME)}) {
			my $GRP = $self->resolve_pretty_grp("S",$S);
			push @RESULTS, [ "$GRP?$ddparams", "Schedule $S ($style)" ];
			}
		}
	elsif ($ddsetid eq 'DOMAINS') {
		require DOMAIN::TOOLS;
		foreach my $D (DOMAIN::TOOLS::domains($USERNAME)) {
			my $GRP = $self->resolve_pretty_grp("D",$D);
			push @RESULTS, [ "$GRP?$ddparams", "Domain $D ($style)" ];
			}
		}
	elsif ($ddsetid eq 'TAGS') {
		foreach my $pis (@ZOOVY::PROD_IS) {
			push @RESULTS, [ sprintf("PIS%02X?$ddparams",$pis->{'bit'}), "Product TAG $pis->{'tag'} ($style)" ];
			}
		}
	elsif ($ddsetid eq 'MARKETS') {
		my %IDS = ();
		foreach my $sref (@ZOOVY::INTEGRATIONS) {
			next if ($IDS{ $sref->{'id'} }); 	# skip duplicate id#
			next if ($sref->{'title'} eq '');
			push @RESULTS, [ sprintf("S%s?$ddparams",$sref->{'dst'}), "Marketplace $sref->{'title'} ($style)" ];
			}	
		}
	else {
		warn "Unknown ddsetid: $ddsetid\n";
		}	
	return(\@RESULTS);
	}

##
## dynamic datasets are used when the number of rows is not known until the report is run.
##
sub dynamic_dsn {
	my ($self,$DDSNID) = @_;
	
	my $USERNAME = $self->username();
	my @RESULTS = ();

	## DDSET will be something like: PRTS?c=2
	if ($DDSNID eq 'PRTS') {
		require ZWEBSITE;
		foreach my $prt (@{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
			push @RESULTS, [ sprintf("PRT%02X",$prt), "Partition $prt" ];
			}
		}
	elsif ($DDSNID eq 'SCHEDULES') {
		require WHOLESALE;
		foreach my $S (@{WHOLESALE::list_schedules($USERNAME)}) {
			my $GRP = $self->resolve_pretty_grp("S",$S);
			push @RESULTS, [ "$GRP", "Schedule $S" ];
			}
		}
	elsif ($DDSNID eq 'DOMAINS') {
		require DOMAIN::TOOLS;
		foreach my $D (DOMAIN::TOOLS::domains($USERNAME)) {
			my $GRP = $self->resolve_pretty_grp("D",$D);
			push @RESULTS, [ "$GRP", "Domain $D" ];
			}
		}
	elsif ($DDSNID eq 'TAGS') {
		foreach my $pis (@ZOOVY::PROD_IS) {
			push @RESULTS, [ sprintf("PIS%02X",$pis->{'bit'}), "Product TAG $pis->{'tag'}" ];
			}
		}
	elsif ($DDSNID eq 'MARKETS') {
		my %IDS = ();
		foreach my $sref (@ZOOVY::INTEGRATIONS) {
			next if ($IDS{ $sref->{'id'} }); 	# skip duplicate id#
			next if ($sref->{'title'} eq '');
			push @RESULTS, [ sprintf("S%s",$sref->{'dst'}), "Marketplace $sref->{'title'}" ];
			}	
		}
	else {
		warn "Unknown ddsetid: $DDSNID\n";
		}	
	return(\@RESULTS);
	}



##
## 
##
sub user_datasets {
	my ($self) = @_;

	my ($MID) = $self->mid();
	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my @RESULTS = ();
	foreach my $r (@KPIBI::DATASETS) {
		push @RESULTS, $r;
		}
	## Partitions
	require ZWEBSITE;
	foreach my $prt (@{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
		push @RESULTS, [ sprintf("PRT%02X?c=1&ctype=\$",$prt), "Partition $prt (GMS \$)" ];
		push @RESULTS, [ sprintf("PRT%02X?c=2&ctype=#",$prt), "Parititon $prt (\# Orders)" ];
		push @RESULTS, [ sprintf("PRT%02X?c=3&ctype=#",$prt), "Parititon $prt (\# Units Sold)" ];

		push @RESULTS, [ sprintf("PRA%02X?c=1&ctype=\$",$prt), "Partition $prt website/A (GMS \$)" ];
		push @RESULTS, [ sprintf("PRA%02X?c=2&ctype=#",$prt), "Parititon $prt website/A (\# Orders)" ];
		push @RESULTS, [ sprintf("PRA%02X?c=3&ctype=#",$prt), "Parititon $prt website/A (\# Units Sold)" ];

		push @RESULTS, [ sprintf("PRB%02X?c=1&ctype=\$",$prt), "Partition $prt website/B (GMS \$)" ];
		push @RESULTS, [ sprintf("PRB%02X?c=2&ctype=#",$prt), "Parititon $prt website/B (\# Orders)" ];
		push @RESULTS, [ sprintf("PRB%02X?c=3&ctype=#",$prt), "Parititon $prt website/B (\# Units Sold)" ];

		push @RESULTS, [ sprintf("PRC%02X?c=1&ctype=\$",$prt), "Partition $prt website/C (GMS \$)" ];
		push @RESULTS, [ sprintf("PRC%02X?c=2&ctype=#",$prt), "Parititon $prt website/C (\# Orders)" ];
		push @RESULTS, [ sprintf("PRC%02X?c=3&ctype=#",$prt), "Parititon $prt website/C (\# Units Sold)" ];
		}

	## Schedules
	require WHOLESALE;
	foreach my $S (@{WHOLESALE::list_schedules($USERNAME)}) {
		my $GRP = $self->resolve_pretty_grp("S",$S);
		push @RESULTS, [ "$GRP?c=1&ctype=\$", "Schedule $S (GMS \$)" ];
		push @RESULTS, [ "$GRP?c=2&ctype=\$", "Schedule $S (\# Orders)" ];
		push @RESULTS, [ "$GRP?c=3&ctype=\$", "Schedule $S (\# Units Sold)" ];
		}
	## Sdomains
	require DOMAIN::TOOLS;
	foreach my $D (DOMAIN::TOOLS::domains($USERNAME)) {
		my $GRP = $self->resolve_pretty_grp("D",$D);
		push @RESULTS, [ "$GRP?c=1&ctype=\$", "Domain $D (GMS \$)" ];
		push @RESULTS, [ "$GRP?c=2&ctype=\$", "Domain $D (\# Orders)" ];
		push @RESULTS, [ "$GRP?c=3&ctype=\$", "Domain $D (\# Units Sold)" ];
		}

	## Coupons
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'C%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "$GRP?c=1&ctype=\$", "Coupon ($GRP) $pretty (GMS \$)" ];
			push @RESULTS, [ "$GRP?c=2&ctype=\$", "Coupon ($GRP) $pretty (\# Orders)" ];
			push @RESULTS, [ "$GRP?c=3&ctype=\$", "Coupon ($GRP) $pretty (\# Units Sold)" ];
			}
		$sth->finish();
		}
	
	##	Product Supplier
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'Q%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "$GRP?c=1&ctype=\$", "Supplier ($GRP) $pretty (GMS \$)" ];
			push @RESULTS, [ "$GRP?c=2&ctype=\$", "Supplier ($GRP) $pretty (\# Orders)" ];
			push @RESULTS, [ "$GRP?c=3&ctype=\$", "Supplier ($GRP) $pretty (\# Units Sold)" ];
			}
		$sth->finish();
		}

	##	Product Affiliate
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'A%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "$GRP?c=1&ctype=\$", "Affiliate ($GRP) $pretty (GMS \$)" ];
			push @RESULTS, [ "$GRP?c=2&ctype=\$", "Affiliate ($GRP) $pretty (\# Orders)" ];
			push @RESULTS, [ "$GRP?c=3&ctype=\$", "Affiliate ($GRP) $pretty (\# Units Sold)" ];
			}
		$sth->finish();
		}

	##	Product Manufacturer
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'M%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "$GRP?c=1&ctype=\$", "Manufacturer ($GRP) $pretty (GMS \$)" ];
			push @RESULTS, [ "$GRP?c=2&ctype=\$", "Manufacturer ($GRP) $pretty (\# Orders)" ];
			push @RESULTS, [ "$GRP?c=3&ctype=\$", "Manufacturer ($GRP) $pretty (\# Units Sold)" ];
			}
		$sth->finish();
		}

	##	Product IS
	foreach my $pis (@ZOOVY::PROD_IS) {
		push @RESULTS, [ sprintf("PIS%02X?c=1&ctype=\$",$pis->{'bit'}), "Product TAG $pis->{'tag'} (GMS \$)" ];
		push @RESULTS, [ sprintf("PIS%02X?c=2&ctype=\#",$pis->{'bit'}), "Product TAG $pis->{'tag'} (\# Orders)" ];
		push @RESULTS, [ sprintf("PIS%02X?c=3&ctype=\#",$pis->{'bit'}), "Product TAG $pis->{'tag'} (\# Units Sold)" ];
		}

	## Marketplace
	push @RESULTS, [ 'FORMULA?c=1&ctype=$&fm=SEBY+SESS', 'eBay Stores + eBay.com (GMS $)' ];
	push @RESULTS, [ 'FORMULA?c=2&ctype=#&fm=SEBY+SESS', 'eBay Stores + eBay.com (# Orders)' ];
	push @RESULTS, [ 'FORMULA?c=3&ctype=#&fm=SEBY+BSESS', 'eBay Stores + eBay.com (# Units Sold)' ];
	push @RESULTS, [ 'FORMULA?c=1&ctype=$&fm=OGMS-(SEBY+SESS)', 'Non eBay Stores + eBay.com (GMS $)' ];
	push @RESULTS, [ 'FORMULA?c=2&ctype=#&fm=OGMS-(SEBY+SESS)', 'Non eBay Stores + eBay.com (# Orders)' ];
	push @RESULTS, [ 'FORMULA?c=3&ctype=#&fm=OGMS-(SEBY+SESS)', 'Non eBay Stores + eBay.com (# Units Sold)' ];
	my %IDS = ();
	my %SGRPIN = ();
	foreach my $sref (@ZOOVY::INTEGRATIONS) {
		next if ($IDS{ $sref->{'id'} }); 	# skip duplicate id#
		next if ($sref->{'title'} eq '');
		push @RESULTS, [ sprintf("S%s?c=1&ctype=\$",$sref->{'dst'}), "Marketplace $sref->{'title'} (GMS \$)" ];
		push @RESULTS, [ sprintf("S%s?c=2&ctype=\#",$sref->{'dst'}), "Marketplace $sref->{'title'} (\# Orders)" ];
		push @RESULTS, [ sprintf("S%s?c=3&ctype=\#",$sref->{'dst'}), "Marketplace $sref->{'title'} (\# Units Sold)" ];
		push @RESULTS, [ sprintf("FORMULA?c=1&ctype=\$&fm=OGMS-S%s",$sref->{'dst'}), "Non $sref->{'title'} (GMS \$)" ];
		push @RESULTS, [ sprintf("FORMULA?c=2&ctype=\#&fm=OGMS-S%s",$sref->{'dst'}), "Non $sref->{'title'} (\# Orders)" ];
		push @RESULTS, [ sprintf("FORMULA?c=3&ctype=\#&fm=OGMS-S%s",$sref->{'dst'}), "Non $sref->{'title'} (\# Units Sold)" ];
		$IDS{$sref->{'id'}}++;
		push @{$SGRPIN{ $sref->{'grp'} }}, "S$sref->{'dst'}";
		}

	foreach my $grpref (@ZOOVY::INTEGRATION_GRPS) {
		next if ($grpref->[0] eq 'WEB');	# web sources is already tracks as 'OWEB'
		my $set = join('+',@{$SGRPIN{ $grpref->[0] }});
		push @RESULTS, [ "FORMULA?c=1&ctype=\$&fm=($set)", "All $grpref->[1] (GMS \$)" ];
		push @RESULTS, [ "FORMULA?c=2&ctype=\#&fm=($set)", "All $grpref->[1] (\# Orders)" ];
		push @RESULTS, [ "FORMULA?c=3&ctype=\#&fm=($set)", "All $grpref->[1] (\# Units Sold)" ];		
		push @RESULTS, [ "FORMULA?c=1&ctype=\$&fm=OGMS-($set)", "Not $grpref->[1] (GMS \$)" ];
		push @RESULTS, [ "FORMULA?c=2&ctype=\#&fm=OGMS-($set)", "Not $grpref->[1] (\# Orders)" ];
		push @RESULTS, [ "FORMULA?c=3&ctype=\#&fm=OGMS-($set)", "Not $grpref->[1] (\# Units Sold)" ];		
		}

	&DBINFO::db_user_close();
	return(@RESULTS);
	}


##
## 
##
## perl -e 'use lib "/backend/lib"; use KPIBI; my ($kpi) = KPIBI->new("beachmart"); use Data::Dumper; print Dumper($kpi->mydatasets());'
sub mydatasets {
	my ($self) = @_;

	my ($MID) = $self->mid();
	my ($USERNAME) = $self->username();	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my @RESULTS = ();
#	push @RESULTS, [ "", 'NULL', 'None' ];
#	push @RESULTS, [ "", 'RANDOM', 'Random Numbers (testing)'];
	## GROUP  DATASET  PRETTY
	push @RESULTS, [ "OVERALL", 'OGMS', 'All Orders' ];
	push @RESULTS, [ "OVERALL", 'OWEB', 'All Website Orders' ];
	push @RESULTS, [ "OVERALL", 'FORMULA:OGMS-OWEB', 'Non Website Orders', "OGMS,OWEB" ];
	push @RESULTS, [ "OVERALL", 'ORPT', 'Repeat Customers' ];
	push @RESULTS, [ "OVERALL", 'FORMULA:OGMS-ORPT', 'New Customers', "OGMS,ORPT" ];
	push @RESULTS, [ "OVERALL", 'OEXP', 'Expedited Shipping' ];
	push @RESULTS, [ "OVERALL", 'FORMULA:OGMS-OEXP', 'Standard Shipping', "OGMS,OEXP" ];
	push @RESULTS, [ "OVERALL", 'OINT', 'International Orders' ];
	push @RESULTS, [ "OVERALL", 'FORMULA:OGMS-OINT', 'Domestic Orders', "OGMS,OINT" ];
	push @RESULTS, [ "OVERALL", 'OGFT', 'Gift Orders' ];
	push @RESULTS, [ "OVERALL", 'FORMULA:OGMS-OGFT', 'Non-Gift Orders', "OGMS,OGFT" ];

	## Partitions
	require ZWEBSITE;
	foreach my $prt (@{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
		push @RESULTS, [ "PARTITION", sprintf("PRT%02X",$prt), "Partition $prt" ];
		push @RESULTS, [ "PARTITION", sprintf("PRA%02X",$prt), "Partition $prt website/A" ];
		push @RESULTS, [ "PARTITION", sprintf("PRB%02X",$prt), "Partition $prt website/B" ];
		push @RESULTS, [ "PARTITION", sprintf("PRC%02X",$prt), "Partition $prt website/C" ];
		}

	## Schedules
	require WHOLESALE;
	foreach my $S (@{WHOLESALE::list_schedules($USERNAME)}) {
		my $GRP = $self->resolve_pretty_grp("S",$S);
		push @RESULTS, [ "SCHEDULE", "$GRP", "$S" ];
		}
	## Sdomains
	require DOMAIN::TOOLS;
	foreach my $D (DOMAIN::TOOLS::domains($USERNAME)) {
		my $GRP = $self->resolve_pretty_grp("D",$D);
		push @RESULTS, [ "DOMAIN", "$GRP", "$D" ];
		}

	## Coupons
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'C%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			push @RESULTS, [ "COUPON", "$GRP", "$pretty" ];
			}
		$sth->finish();
		}
	
	##	Product Supplier
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'Q%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "SUPPLIER", "$GRP", "$pretty" ];
			}
		$sth->finish();
		}

	##	Product Affiliate
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'A%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "AFFILIATE", "$GRP", "$pretty" ];
			}
		$sth->finish();
		}

	##	Product Manufacturer
	if (1) {
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID /* $USERNAME */ and GRP like 'M%' order by ID desc";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($GRP,$pretty) = $sth->fetchrow() ) {
			$pretty = &ZOOVY::incode($pretty);
			push @RESULTS, [ "MANUFACTURER", "$GRP", "$pretty" ];
			}
		$sth->finish();
		}

	##	Product IS
	foreach my $pis (@ZOOVY::PROD_IS) {
		push @RESULTS, [ "PRODUCT_TAG", sprintf("PIS%02X",$pis->{'bit'}), "$pis->{'tag'}" ];
		}

	## Marketplace
	push @RESULTS, [ "MARKETPLACE", 'FORMULA:SEBY+SESS', 'eBay Stores + eBay.com' ];
	push @RESULTS, [ "MARKETPLACE", 'FORMULA:OGMS-(SEBY+SESS)', 'Non eBay Stores + eBay.com (GMS $)' ];
	my %IDS = ();
	my %SGRPIN = ();
	foreach my $sref (@ZOOVY::INTEGRATIONS) {
		next if ($IDS{ $sref->{'id'} }); 	# skip duplicate id#
		next if ($sref->{'title'} eq '');
		push @RESULTS, [ "MARKETPLACE", sprintf("S%s",$sref->{'dst'}), "$sref->{'title'}" ];
		push @RESULTS, [ "MARKETPLACE", sprintf("FORMULA:OGMS-S%s",$sref->{'dst'}), "Non $sref->{'title'}" ];
		$IDS{$sref->{'id'}}++;
		push @{$SGRPIN{ $sref->{'grp'} }}, "S$sref->{'dst'}";
		}

	foreach my $grpref (@ZOOVY::INTEGRATION_GRPS) {
		next if ($grpref->[0] eq 'WEB');	# web sources is already tracks as 'OWEB'
		my $set = join('+',@{$SGRPIN{ $grpref->[0] }});
		push @RESULTS, [ "OTHER", "FORMULA:($set)", "All $grpref->[1]" ];
		push @RESULTS, [ "OTHER", "FORMULA:OGMS-($set)", "Not $grpref->[1]" ];
		}

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}



# dates are stored as "DT" - which is described below:
# structure of DT
#  	10jjj   (2010 with 3 digit day of year)
# 
#create table KPI_SALES (
#   ID bigint unsigned auto_increment,
#   MID integer unsigned default 0 not null,
#   DT integer unsigned default 0 not null,
#   GRP varchar(4) default '' not null,
#   GRPOPT tinytext default null,
#   STAT_GMS integer unsigned default 0 not null,
#   STAT_INC integer unsigned default 0 not null,
#   STAT_UNITS integer unsigned default 0 not null,
#   primary key (ID),
#   unique(MID,DT,DSTCODE,DSTOPT)
#);


## UTILITY FUNCTIONS:
######################################
sub array_max {
	my ($ar) = @_;
	my $max = undef;
	foreach my $v (@{$ar}) {
		if (not defined $max) { $max = $v; }
		elsif ($v > $max) { $max = $v; }
		}
	return($max);
	}

##
## purpose: takes an array of values, and a count then provides a new array
##				with count elements, evenlly pulled form a distribution of the original array of values
##
sub array_xvals {
	my ($ar,$count) = @_;

	my @result = ();
	if (scalar(@{$ar})<=$count) {
		@result = @{$ar};
		}
	else {
		my $step = int(scalar(@{$ar})/$count);
		my $i = 0;
		while ( $i*$step < scalar(@{$ar}-1) ) {
			$result[$i] = $ar->[$i*$step];
			$i++;
			}
		$result[$i] = $ar->[ scalar(@{$ar})-1 ];
		}
	return(@result);
	}

$::LocalTZ = DateTime::TimeZone->new( name => 'local');

#######################################
##
## this takes a series of dates (lets say 90 days) and summarizes them.
##
sub summarize_series {
	my ($seriesref,,%options) = @_;

	my @result = ();
	if ($options{'groupby'} eq 'week') {	
		}
	elsif ($options{'groupby'} eq 'month') {
		}

	return(\@result);
	}



###############################################################
##
## returns an array of all dates between $startdt, and $stopdt
##
## perl -e 'use lib "/backend/lib"; use KPIBI; use Data::Dumper; print Dumper(KPIBI::dt_series("10001","11001"));'
##
sub dt_series {
	my ($startdt,$stopdt) = @_;
	
	my $startyear = substr(sprintf("%05",$startdt),0,2);
	my $stopyear = substr(sprintf("%05",$stopdt),0,2);

	my @result = ();
	my $now = $startdt;
	while ($now < $stopdt) {
		$now = sprintf("%05d",$now);
		push @result, $now;
		my $yr = substr($now,0,2);
		my $day = substr($now,2);
		$day++;
		if ($day>365) {
			if ((($yr+2000) % 4)==0) {
				## leap year (366 days) 
				if ($day>366) { $yr++; $day = 1; }
				}
			else {
				## non-leap year
				$yr++;
				$day = 1;
				}
			$now = sprintf("%02d%03d",$yr,$day);
			}
		else {
			$now++;
			}
		}
	return(@result);
	}


# perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::dt_to_yyyymmdd(KPIBI::ts_to_dt(time()));'
sub dt_to_yyyymmdd {
	my ($dt) = @_;
	my ($yy,$jjj) = (substr($dt,0,2),substr($dt,2,3));
	$yy+=2000;
	my ($y,$m,$d) = Date::Calc::Add_Delta_Days($yy,1,1, int($jjj)-1);
	return(sprintf("%04d%02d%02d",$y,$m,$d));	
	}


# perl -e 'use lib "/backend/lib"; use KPIBI; print "HOUR IS: ".((time()- KPIBI::dt_to_ts(KPIBI::ts_to_dt(time())))/3600);'
sub dt_to_ts {
	my ($dt) = @_;
	my ($yy,$jjj) = (substr($dt,0,2),substr($dt,2,3));
	$yy += 2000;
	my ($y,$m,$d) = Date::Calc::Add_Delta_Days($yy,1,1, int($jjj)-1);
	my ($ts) = Date::Calc::Mktime($y,$m,$d,0,0,0);
	return($ts);
	}


# return the next dt in the sequence, with speed optimizations/ shortcuts for situations where it's NOT a leap year
sub next_dt {
	my ($dt) = @_;
	
	my $day = substr($dt,2,3);
	if ($day<365) {
		## no worries, just go to the next day!
		++$dt;
		}
	else {
		my ($yy,$jjj) = (substr($dt,0,2),substr($dt,2,3));
		$yy+=2000;
		my ($y,$m,$d) = Date::Calc::Add_Delta_Days($yy,1,1, int($jjj));
		$dt = yyyymmdd_to_dt(sprintf("%04d%02d%02d",$y,$m,$d));
		}
	return($dt);
	}


sub dt_to_shortpretty {
	my ($dt) = @_;
	return(&ZTOOLKIT::pretty_date(KPIBI::dt_to_ts($dt),-3));
	}

# perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::yyyymmdd_to_dt("20101216");'
sub yyyymmdd_to_dt {
	my ($yyyymmdd) = @_;

	my ($yyyy) = substr($yyyymmdd,0,4);
	my ($mm) = substr($yyyymmdd,4,2);
	my ($dd) = substr($yyyymmdd,6,2);

	#if ($mm eq '00') { 
	#	die("Date: $yyyymmdd is invalid");
	#	}

	my $dt = DateTime->new(
      year       => $yyyy,
      month      => $mm,
      day        => $dd,
      time_zone  => $::LocalTZ
		);
	return(ts_to_dt($dt->epoch()));
	}

## converts an epoch timestamp to a dt
# perl -e 'use lib "/backend/lib"; use KPIBI; print KPIBI::ts_to_dt(time());'
sub ts_to_dt {
	my ($ts) = @_;
	return(strftime("%y%j",localtime($ts)));
	}

## 
sub dt_to_none {
	my ($dt) = @_;
	return(''); 
	}


##
## this returns the following: 
## perl -e 'use lib "/backend/lib"; use Data::Dumper; use KPIBI; print Dumper(KPIBI::initialize_xaxis("11032","11095","month"));
## 
sub initialize_xaxis {
	my ($dtstart,$dtstop,$grpby) = @_;

	my $GRPBY_FUNCTION = undef;
	if ($grpby eq 'day') { $GRPBY_FUNCTION = \&dt_to_day; }
	elsif ($grpby eq 'dow') { $GRPBY_FUNCTION = \&dt_to_dow; }
	elsif ($grpby eq 'quarter') { $GRPBY_FUNCTION = \&dt_to_quarter; }
	elsif ($grpby eq 'month') { $GRPBY_FUNCTION = \&dt_to_month; }
	elsif ($grpby eq 'week') { $GRPBY_FUNCTION = \&dt_to_week; }
	elsif ($grpby eq 'none') { $GRPBY_FUNCTION = \&dt_to_none; }
	else { 
		warn "Unknown grpby:$grpby, defaulting to 'day' summarization\n";
		$GRPBY_FUNCTION = \&dt_to_day; 
		}
	

	# print Dumper(\%DT_INDEX);
	## SANITY: at this point %DT_INDEX is populated, so we go through each day to make sure we have a row (or add a zero data set)
	my %DT_LOOKUP = ();
	my %GRPBY_DATA = ();	# keeps track of which summaries have been seen before, set to a blank array (which will eventually contain data)
	my @GRPBY_SEQUENCE = ();	# a list of summaries (in the proper order they will be displayed)
	while ($dtstart < $dtstop) {
		my $summary = $GRPBY_FUNCTION->($dtstart);
		$DT_LOOKUP{ $dtstart } = $summary;
		if (not defined $GRPBY_DATA{$summary}) {
			push @GRPBY_SEQUENCE, $summary;
			$GRPBY_DATA{$summary} = []; 	# make sure we don't add this one again
			}
		$dtstart = &KPIBI::next_dt($dtstart);
		}

	return(\%DT_LOOKUP,\@GRPBY_SEQUENCE);
	}



##
##
##  perl -e 'use lib "/backend/lib"; use KPIBI; use Data::Dumper; print Dumper(KPIBI::relative_to_current("year.last"));'
sub relative_to_current {
	my ($request) = @_;

	my $startyyyymmdd = 0;
	my $stopyyyymmdd = 0;


	##
	## Time periods are assumed to be midnight through midnight
	my @TODAY = Date::Calc::Today();
	my @START = ();
	my @STOP = ();
	if ($request eq 'day.today') {
		#	<option value="days.0">Today</option>
		@START = @TODAY;
		@STOP = Date::Calc::Add_Delta_Days(@TODAY,+1);
		}
	elsif ($request eq 'day.yesterday') {
		#	<option value="day.today">Today</option>
		#	<option value="day.yesterday">Yesterday</option>
		@START = Date::Calc::Add_Delta_Days(@TODAY,-1);
		@STOP = @TODAY;
		}
	elsif ($request =~ /^days\.([\d]+)$/) {
		#	<option value="days.7">Last 7 Days</option>
		#	<option value="days.10">Last 10 Days</option>
		#	<option value="days.14">Last 14 Days</option>
		#	<option value="days.21">Last 21 Days</option>
		#	<option value="days.28">Last 28 Days</option>
		my ($days) = int($1);
		@START = Date::Calc::Add_Delta_Days(@TODAY,-$days);
		@STOP = Date::Calc::Add_Delta_Days(@TODAY, 0);
		}
	elsif ($request =~ /^quarter\.(this|tly|last)$/) {
		#	<option value="quarter.this">This Quarter</option>
		#	<option value="quarter.tly">This Quarter Last Year</option>
		#	<option value="quarter.last">Last Quarter</option>
		my ($type) = $1;
		@START = @TODAY;
		$START[2] = 1; 	# first day of the quarter
		## now figure out which quarter!
		if ($START[1]>=10) { $START[1] = 10; }
		elsif ($START[1]>=7) { $START[1] = 7; }
		elsif ($START[1]>=4) { $START[1] = 4; }
		elsif ($START[1]>=1) { $START[1] = 1; }
		if ($type eq 'tly') {
			@START = Date::Calc::Add_Delta_YM(@START, -1, 0);
			}
		elsif ($type eq 'last') {
			@START = Date::Calc::Add_Delta_YM(@START, 0, -1);			
			}
		@STOP = Date::Calc::Add_Delta_YM(@START, 0, 3);
		}
	elsif ($request =~ /^month\.(this|tly|last)$/) {
		#	<option value="month.this">This Month</option>
		#	<option value="month.tly">This Month Last Year</option>
		#	<option value="month.last">Last Month</option>
		my ($type) = $1;
		@START = ($TODAY[0],$TODAY[1],1);	# copy year, month, but set day to 1
		if ($type eq 'this') {
			}
		elsif ($type eq 'last') {
			@START = Date::Calc::Add_Delta_YM(@START,0,-1);
			}
		elsif ($type eq 'tly') {
			@START = Date::Calc::Add_Delta_YM(@START,-1,0);
			}
		@STOP = Date::Calc::Add_Delta_YM(@START,0,1);
		}
	elsif ($request =~ /^year\.(this|last)$/) {
		#	<option value="year.this">This Year</option>
		#	<option value="year.last">Last Year</option>
		my ($type) = $1;
		@START = ($TODAY[0],1,1);	# copy year, but set month, day to 1
		if ($type eq 'this') {
			}
		elsif ($type eq 'last') {
			@START = Date::Calc::Add_Delta_YM(@START,-1,0);
			}
		@STOP = Date::Calc::Add_Delta_YM(@START,1,0);
		}
	elsif ($request =~ /^week\.(this|tly|last)$/) {
		#	<option value="week.this">This Week</option>
		#	<option value="week.tly">This Week Last Year</option>
		#	<option value="week.last">Last Week</option>
		my ($type) = $1;
		@START = Date::Calc::Monday_of_Week(Date::Calc::Week_of_Year(@TODAY));
		if ($type eq 'this') {
			@STOP = @TODAY;
			}
		elsif ($type eq 'last') {
			@STOP = @START;
			@START = Date::Calc::Add_Delta_YMD(@START,0,0,-7);
			}
		elsif ($type eq 'tly') {
			@START = Date::Calc::Add_Delta_YMD(@START,-1,0,0);
			@STOP = Date::Calc::Add_Delta_YM(@START,0,0,+7);			
			}
		}
	elsif ($request =~ /^weeks\.([\d]+)$/) {
		#	<option value="weeks.1">This Week + 1 week</option>
		my ($weeks) = int($1);
		@STOP = @TODAY;
		@START = Date::Calc::Monday_of_Week(Date::Calc::Week_of_Year(@TODAY));
		@START = Date::Calc::Add_Delta_Days(@START,0-($weeks * 7));			
		}
	elsif ($request =~ /^ytd.(this|last)$/) {
		#	<option value="ytd.this">Year-To-Date</option>
		#	<option value="ytd.last">Last Year</option>
		my ($type) = $1;
		@START = @TODAY;
		$START[2] = 1; # first day of the year
		$START[1] = 1; # first month of the year
		if ($type eq 'this') {
			}
		elsif ($type eq 'last') {
			$START[0] -= 1;	# last year, subtract 1
			}
		@STOP = @START;
		$STOP[0] += 1; 	# stop on the last day of the year.
		}
	elsif ($request =~ /^months\.([\d]+)$/) {
		# 'This Month + # Prior Months'
		my ($months) = $1;
		@START = @TODAY;
		@STOP = @TODAY;
		$START[2] = 1; # go to first day of this month
		# now subtract 3 (or whatever) months
		@START = Date::Calc::Add_Delta_YMD(@START,0,0-$months,0);
		}
	else {
		warn "Relative to current got no period passed - using tomorrow\n";
		@START = Date::Calc::Add_Delta_YMD(@TODAY,0,0,1);
		@STOP = @START;
		}

	$startyyyymmdd = sprintf("%04d%02d%02d",@START);
	$stopyyyymmdd = sprintf("%04d%02d%02d",@STOP);

	return($startyyyymmdd,$stopyyyymmdd);
	}




#######################################################################################


##
## this is used by the recompile stats function to remove a grp 
##
sub stat_nuke {
	my ($USERNAME,$DT,$GRP,$GRPOPT) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::db_user_close();
	}



##
## a set is an array of data that should be added or incremented
##	for example: 
##	[ '=', 'OGMS', $ts, 0(gms), $inc, $units ]	
##
sub stats_store {
	my ($self, $kpistats) = @_;
	
	my $MID = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	foreach my $set (@{$kpistats}) {
		my ($prefix,$key,$ts,$gms,$inc,$units) = @{$set};
		$gms *= 100;	# we don't store decimals!
		my $lookup_type = substr($prefix,0,1);
		my $GRP = substr($prefix,1);	
		## note: prefix is what is pre-pended to key, it also serves as "type" in a number of lookups
		## it's okay if this is "" (especially for some of lookup_type ='s because they are implicitly set e.g. OGMS: overvall gms sales)
		if ($lookup_type eq '=') {
			## = "literal string" example:
			## =PRE??? PRE???
			$GRP .= $key;
			}
		elsif ($lookup_type eq '~') {
			## ~ soundex lookup
			($GRP) = $self->resolve_soundex_grp($GRP,$key);
			}
		elsif ($lookup_type eq '$') {
			## ~ string lookup
			($GRP) = $self->resolve_pretty_grp($GRP,$key);
			}

		my $DT = KPIBI::ts_to_dt($ts);
		my $pstmt = "update $self->{'_KPITB'} set STAT_GMS=STAT_GMS+$gms,STAT_INC=STAT_INC+$inc,STAT_UNITS=STAT_UNITS+$units where MID=$MID and DT=$DT and GRP=".$udbh->quote($GRP);
		my ($rows) = $udbh->do($pstmt);
		if ($rows>0) {
			$pstmt = undef;
			}
		else {
			## uh-oh, didn't insert
			($pstmt) = &DBINFO::insert($udbh,$self->{'_KPITB'},{
				'MID'=>$MID,
				'DT'=>$DT,
				'GRP'=>$GRP,
				'STAT_GMS'=>$gms,
				'STAT_INC'=>$inc,
				'STAT_UNITS'=>$units
				},sql=>1);
			# print STDERR $pstmt."\n";
			if ($udbh->do($pstmt)) { $pstmt = undef; }
			}

		if ($pstmt) {
			## something went horribly wrong!
			open F, sprintf(">>%s/stats.err",&ZOOVY::tmpfs());
			print F time()."|".$self->username()."|$GRP|$DT|$gms|$inc|$units\n";
			close F;
			}
		}
	&DBINFO::db_user_close();
	}

##
##
##
sub stat_set {
	my ($USERNAME,$DT,$GRP,$GMS,$INC,$UNITS) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::db_user_close();
	}


##
## this takes a text item like:  "dans fish n chips" and converts it to a soundex value which it then attempts to lookup
##	into the database types are:
##		M for MFG
##		Q for Supplier
##		C for Coupon
##		D domain
##
#create table KPI_GRP_LOOKUP (
#   ID integer unsigned not null auto_increment,
#   MID integer unsigned default 0 not null,
#   GRP varchar(5) default '' not null,
#   SOUNDEX varchar(6) default '' not null,
#   PRETTY varchar(30) default '' not null,
#   primary key (ID),
#   unique(MID,GRP),
#   unique(MID,SOUNDEX)
#);

# perl -e 'use lib "/backend/lib"; use KPIBI; my ($kpi) = KPIBI->new("brian"); print $kpi->resolve_soundex_grp("X","Testing")."\n";'
sub resolve_soundex_grp {
	my ($self,$TYPE,$KEY,%options) = @_;
	$TYPE = substr($TYPE,0,1);

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $cleankey = uc($KEY);
	$cleankey =~ s/[\s]+//gs;	 #remove spaces
	$cleankey =~ s/[^\w]+//gs;	 # remove punctuation
	$cleankey =~ s/s$//gs;		# remove trailing 's
	my $KEYSOUNDEX = substr(Text::Soundex::soundex($cleankey),0,4);


	my $GRP = undef;
	my $ref = $self->{"%$TYPE!"};	 # note: this will be undef unless the response is cached

	if (defined $GRP) {
		## WTF? - this should NEVER be true!
		}
	elsif (defined $ref) {
		$GRP = $ref->{"$KEYSOUNDEX"};
		}
	elsif (not defined $self->{"%$TYPE!"}) {
		$ref = {};
		$self->{"%$TYPE!"} = $ref;
		my $MID = $self->mid();
		my $pstmt = "select GRP,SOUNDEX from KPI_GRP_LOOKUP where MID=$MID and GRP like '$TYPE%'";
		# print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($grp,$soundex) = $sth->fetchrow() ) {
			$ref->{$soundex} = $grp;
			}
		$sth->finish();
		$GRP = $ref->{"$KEYSOUNDEX"}; # this will be true if it's in the database already (but we hadn't loaded it)
		}

	## SANITY: at this point $GRP is either set, or we need to add it to db, and resident hash

	if (defined $GRP) {
		}
	else {
		## for SOUNDEX the GRP is always known (it's XYYYY where X=type, YYYY=soundex) so we can add it quickly without using a counter.
		$GRP = "$TYPE$KEYSOUNDEX";
		my $pstmt = &DBINFO::insert($udbh,'KPI_GRP_LOOKUP',{
			MID=>$self->mid(),
			GRP=>$GRP,
			SOUNDEX=>$KEYSOUNDEX,
			PRETTY=>$KEY
			},sql=>1);
		$udbh->do($pstmt);
		$ref->{"$KEYSOUNDEX"} = $GRP;
		}	

	&DBINFO::db_user_close();
	return($GRP);
	}


##
##
##
sub resolve_pretty_grp {
	my ($self,$TYPE,$KEY,%options) = @_;
	$TYPE = substr($TYPE,0,1);

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	my ($MID) = $self->mid();
	my $GRP = undef;
	my $ref = $self->{"%$TYPE"};

	if (not defined $ref) {
		## no lookup table, try and load it.
		$ref = {};
		$self->{"%$TYPE"} = $ref;
		my $pstmt = "select GRP,PRETTY from KPI_GRP_LOOKUP where MID=$MID and GRP like '$TYPE%'";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($dbgrp,$dbpretty) = $sth->fetchrow() ) {
			$ref->{$dbpretty} = $dbgrp;
			}
		$sth->finish();
		$GRP = $ref->{"$KEY"};
		}
	else {
		$GRP = $ref->{"$KEY"};
		}

	## SANITY: at this point $GRP is either set, or we need to add it to db, and resident hash

	if (not defined $GRP) {
		my $MID = $self->mid();
		my $pstmt = "select I from KPI_GRP_COUNTER where MID=$MID and GRPTYPE='$TYPE'";
		my ($i) = $udbh->selectrow_array($pstmt);
		if (not defined $i) {
			my ($pstmt) = &DBINFO::insert($udbh,'KPI_GRP_COUNTER',{'MID'=>$MID,'I'=>1,'GRPTYPE'=>$TYPE},sql=>1);
			$udbh->do($pstmt);
			$i=1;
			}
		else {
			$pstmt = "update KPI_GRP_COUNTER set I=I+1 where MID=$MID and GRPTYPE='$TYPE'";
			$udbh->do($pstmt);
			$i++;
			}
		$GRP = sprintf("%s%s",$TYPE,&ZTOOLKIT::base36($i));
		($pstmt) = &DBINFO::insert($udbh,'KPI_GRP_LOOKUP',{
			MID=>$self->mid(),
			GRP=>$GRP,PRETTY=>$KEY
			},sql=>1);
		# print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		$ref->{"$KEY"} = $GRP;
		}

	&DBINFO::db_user_close();
	return($GRP);
	}




##
## returns a data set, which is an arrayref of arrays
##		each array contains:
##			[0] dt
##			[1] gms#
##			[2] inc#
##			[3] units#
##			[4] grp
##
## $startyyyymmdd $stopyyyymmdd
#  perl -e 'use lib "/backend/lib"; use Data::Dumper; use KPIBI; my ($KPI) = KPIBI->new("toynk",0); print Dumper($KPI->get_data("OGMS?x=not_important","20100101","20110301"));'

sub get_data {
	my ($self,$DSN,$START_YYYYMMDD,$STOP_YYYYMMDD) = @_;

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my ($ID,$DSNPARAMS) = ($DSN,{});
	if (index($DSN,'?')>-1) {
		($ID,$DSNPARAMS) = &ZTOOLKIT::dsnparams($DSN);
		}

	my $FORMULA = undef;
	if (defined $DSNPARAMS->{'fm'}) { $FORMULA = $DSNPARAMS->{'fm'}; }
	if ($ID =~ /^FORMULA\:(.*?)$/) { $FORMULA = $1; }


	my ($dtstart) = &KPIBI::yyyymmdd_to_dt($START_YYYYMMDD);
	my ($dtstop) = &KPIBI::yyyymmdd_to_dt($STOP_YYYYMMDD);
	my @RESULTS = ();
	if (($ID eq 'null') || ($ID eq 'NULL')) {
		}
	elsif (($ID eq 'random') || ($ID eq 'RANDOM')) {
		## random data provider
		if (not $KPIBI::SRANDED) {
			srand(time ^ ($$ + ($$ << 15)));
			$KPIBI::SRANDED++;
			}
		
		## this is wrong because it assumes there are 100 days per month.
		#foreach my $dt ($dtstart..($dtstop-1)) {
		#	push @RESULTS, [ $dt, int(rand(10000)), 1, int(rand()*10) ];
		#	}
		while ($dtstart < $dtstop) {
			push @RESULTS, [ $dtstart, int(rand(10000)), 1, int(rand()*10) ];
			$dtstart = &KPIBI::next_dt($dtstart);
			}
		}
	elsif ($FORMULA) {
		##
		## WOW!! xa computed formula field! something like: fm=OGMS-OEXP
		## 	
		my @TBDBHS = ( [$self->tb(),$udbh] );
		my %IDS = ();
		foreach my $id (split(/[\+\-\*\/]+/,$FORMULA)) {
			$id =~ s/[^A-Z0-9]+//gs;
			$IDS{$id}++;
			}
		my @IDS = sort keys %IDS;
		# print STDERR Dumper(\@IDS);
		my $qtSET = &DBINFO::makeset($udbh,\@IDS);

		my %DTS = ();
		foreach my $tbdbhset (@TBDBHS) {
			my ($tb,$xdbh) = @{$tbdbhset};
			my $pstmt = sprintf("select DT,STAT_GMS,STAT_INC,STAT_UNITS,GRP from %s where ",$tb);
			$pstmt .= sprintf(" DT>=%d and DT<%d and GRP in %s",$dtstart,$dtstop,$qtSET);
			# print STDERR $pstmt."\n";
			my ($sth) = $xdbh->prepare($pstmt);
			$sth->execute();
			while ( my @row = $sth->fetchrow() ) {
				## alright, so we crate a hashref with the following structure:
				## %DTS{'dt1'}->{'ID1'} = [..dataset..]
				## %DTS{'dt1'}->{'ID2'} = [..dataset..]
				## that way later on we can go through and run Math Symbolic over the top
				if ($row[1]>1000000) { 
					## cheap hack, limit people to 1,000,000 days.
					$row[1] = 1000000;
					}

				if (not defined $DTS{ $row[0] }->{ $row[4] }) {
					$DTS{ $row[0] }->{ $row[4] } = \@row;
					}
				else {
					## add to the existing columns (useful for aggregating)
					$DTS{ $row[0] }->{ $row[4] }->[1] += $row[1];
					$DTS{ $row[0] }->{ $row[4] }->[2] += $row[2];
					$DTS{ $row[0] }->{ $row[4] }->[3] += $row[3];
					}
				}
			$sth->finish();
			}

		require Math::Symbolic;
		my $tree = Math::Symbolic->parse_from_string($FORMULA);
		my ($sub) = Math::Symbolic::Compiler->compile_to_sub($tree);

		foreach my $dt (keys %DTS) {
			my $gms = 0;
			my $inc = 0;
			my $units = 0;
			foreach my $c (1..3) {
				my @VALS = ();
				foreach my $id (@IDS) {
					if (not defined $DTS{ $dt }) { push @VALS, 0; }
					elsif (not defined $DTS{ $dt }->{ $id }) { push @VALS, 0; }
					else { push @VALS, $DTS{ $dt }->{ $id }->[$c]; }
					}
				## SANITY: at this point @VALS is the alphanumerically sorted, numeric values for each id in a formula ex:
				## formula OGMS-OEXP (note: OEXP comes before OGMS) if OGMS=10 and OEXP=5 then @VALS contains [5,10]
				## this is how math symbolic works, i didn't make it up!
				if ($c == 1) { $gms = $sub->(@VALS); }
				if ($c == 2) { $inc = $sub->(@VALS); }
				if ($c == 3) { $units = $sub->(@VALS); }
				}
			my @row = ( $dt, $gms, $inc, $units, $ID );
			push @RESULTS, \@row;
			}
		# print STDERR Dumper(\@RESULTS); die();
		}
	else {
		## real data! directed lookup (fastest)
		## NOTE: not compatible with aggregating
		my $qtGRP = $udbh->quote($ID);
		my $pstmt = sprintf("select DT,STAT_GMS,STAT_INC,STAT_UNITS,GRP from %s where ",$self->tb());
		$pstmt .= sprintf("DT>=%d and DT<%d and GRP=%s",$dtstart,$dtstop,$qtGRP);
		print STDERR $pstmt."\n";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my @row = $sth->fetchrow() ) {
			push @RESULTS, \@row;
			}
		$sth->finish();
		}

	#open F, ">>/tmp/results";
	#print F Dumper(\@RESULTS);
	#close F;
	&DBINFO::db_user_close();


	return(\@RESULTS);
	}



##
##
sub get_graphref {
	my ($self,$id) = @_;

	my $graphref = undef;
	foreach my $thisref (@KPIBI::GRAPHS) {
		if ($thisref->{'id'} eq $id) { $graphref = $thisref; }
		}
	return($graphref);
	}


##
## if UUID is blank then we create a new graph
##
sub store_graphcfg {
	my ($self, $GUID, $GRAPH, $TITLE, $COLLECTION, $config) = @_;

	if ($COLLECTION == 0) {
		$COLLECTION = $self->create_collection($TITLE);
		}

	if ((not defined $GUID) || ($GUID eq '')) {
		require Data::GUID;
		$GUID = Data::GUID->new()->as_string();
		}
	## NOTE: UUID column in database is 40 characters *MAX*
	$GUID = substr($GUID,0,40);

	# print STDERR "USERNAME: ".$self->username()." MID: ".$self->mid()."\n";
	my %vars = (
		'USERNAME'=>$self->username(),
		'MID'=>$self->mid(),
		'GRAPH'=>$GRAPH,
		'UUID'=>$GUID,
		'COLLECTION'=>$COLLECTION,
		'TITLE'=>$TITLE,
		'SIZE'=>$config->{'size'},
		'PERIOD'=>$config->{'period'},
		'GRPBY'=>$config->{'grpby'},
		'COLUMNS'=>$config->{'columns'},
		'*CREATED'=>'now()',
		'CONFIG'=>YAML::Syck::Dump($config),
		'IS_SYSTEM'=>0,
		);

	my ($udbh) = &DBINFO::db_user_connect($self->username());	
	## there's some wonky issue with not being able to delete.
	## actually the issue was that the guid field was longer than the original 32 characters alloted, hopefully 64 is better.
	my $pstmt = "delete from KPI_USER_GRAPHS where MID=".$udbh->quote($self->mid())." and UUID=".$udbh->quote($GUID);
	# print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	($pstmt) = &DBINFO::insert($udbh,'KPI_USER_GRAPHS',\%vars,key=>['MID','UUID'],sql=>1);
	# print STDERR Dumper($pstmt,\%vars);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	return($GUID);
	}


##
##
##
sub save_collection_order {
	my ($self,$collection,$guidsarref) = @_;

	my ($MID) = int($self->mid());
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	## first, reset the sort order
	my $pstmt = "update KPI_USER_GRAPHS set SORT_ORDER=0 where MID=$MID and COLLECTION=".int($collection);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	my $i = 1;
	foreach my $guid (@{$guidsarref}) {
		my $pstmt = "update KPI_USER_GRAPHS set SORT_ORDER=$i where MID=$MID and UUID=".$udbh->quote($guid);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		$i++;
		}

	&DBINFO::db_user_close();
	return($i);
	}


##
##
# perl -e 'use lib "/backend/lib"; use KPIBI; my ($k) = KPIBI->new("liz","0"); use Data::Dumper; print Dumper($k); print Dumper($k->list_graphcfgs(COLLECTION=>2));'
sub list_graphcfgs {
	my ($self,%options) = @_;
	my ($udbh) = &DBINFO::db_user_connect($self->username());	
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	my $pstmt = "select * from KPI_USER_GRAPHS where MID=$MID /* $USERNAME */ ";
	if ($options{'UUID'}) { $pstmt .= " and UUID=".$udbh->quote($options{'UUID'}); }
	if ($options{'COLLECTION'}) { $pstmt .= " and COLLECTION=".int($options{'COLLECTION'}); }
	$pstmt .= " order by SORT_ORDER asc,CREATED desc";
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my @RESULT = ();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		$ref->{'%'} = YAML::Syck::Load($ref->{'CONFIG'});
		delete $ref->{'CONFIG'};
		push @RESULT, $ref;	
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULT);
	}


##
##
##
sub get_graphcfg {
	my ($self, $UUID) = @_;
	my $r = undef;
	my ($results) = $self->list_graphcfgs(UUID=>$UUID);
	if (scalar(@{$results})>0) { $r = $results->[0]; }
	return($r);
	}


##
##
sub nuke_graphcfg {
	my ($self, $GUID) = @_;
	my ($udbh) = &DBINFO::db_user_connect($self->username());	
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	my $pstmt = "delete from KPI_USER_GRAPHS where MID=$MID /* $USERNAME */ and UUID=".$udbh->quote($GUID);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return(0);
	}



##
##
##
sub username { return(lc($_[0]->{'_USERNAME'})); }
sub mid { return($_[0]->{'_MID'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub set_prt { $_[0]->{'_PRT'} = $_[1]; }
sub tb { return($_[0]->{'_KPITB'}); }
#sub udbh { 
#	if (not defined $_[0]->{'*DBI'}) {
#		$_[0]->{'*DBI'} = &DBINFO::db_user_connect($_[0]->username());
#		}
#	return($_[0]->{'*DBI'}); 
#	}


##
## 
##
sub new {
	my ($class,$USERNAME,$PRT) = @_;

	my $self = {};
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MID'} = $MID;
	$self->{'_PRT'} = $PRT;
	$self->{'*DBI'} = undef;
	my $TBMID = $MID;
	if ($MID%10000>0) { $TBMID = $MID -($MID % 10000); }		
	$self->{'_KPITB'} = 'KPI_STATS_'.$TBMID;
	if (&ZOOVY::myrelease($USERNAME)>201338) { 
		$self->{'_KPITB'} = 'KPI_STATS';
		}

	bless $self, 'KPIBI';
	return($self);
	}

##
## clean up the database handle
## 
#sub DESTROY {	
#	my $self = shift;
#	if (defined $self->{'*DBI'}) {
#		&DBINFO::db_user_close();
#		$self->{'*DBI'} = undef;
#		}
#	return();
#	}


##
## this does the heavy lifting by generating the high charts javascript object
##
sub makejson {
	my ($self,$g,$containerid) = @_;

		my $UUID = $g->{'UUID'};

		my $JSUUID = "graph$UUID";
		$JSUUID =~ s/-//gs;
		
		my @xAxis = ();
		#push @xAxis, 'Lions';
		#push @xAxis, 'Tigers';
		#push @xAxis, 'Bears';

		my ($startyyyymmdd,$stopyyyymmdd) = &KPIBI::relative_to_current($g->{'%'}->{'period'});
		$g->{'%'}->{'startyyyymmdd'} = $startyyyymmdd;
		$g->{'%'}->{'stopyyyymmdd'} = $stopyyyymmdd;

		## figure out how many ticks we're going to have, make sure we summarize properly.
		my ($package,$file,$line,$sub,$args) = caller(0);
		print STDERR "(PERIOD:$g->{'%'}->{'period'}) ($startyyyymmdd) $package $file $line $sub $args\n";
		
		my ($startdt) = &KPIBI::yyyymmdd_to_dt($startyyyymmdd);
		my ($stopdt) = &KPIBI::yyyymmdd_to_dt($stopyyyymmdd);
		$g->{'%s'}->{'startdt'} = $startdt;
		$g->{'%s'}->{'stopdt'} = $stopdt;
		my ($dtlookup,$grpby_sequence) = &KPIBI::initialize_xaxis($startdt,$stopdt,$g->{'%'}->{'grpby'});
		@xAxis = @{$grpby_sequence};

		# print STDERR Dumper($startdt,$stopdt,'month'); die();

		
		my $COLUMNS = $g->{'COLUMNS'};
		if ($COLUMNS == 0) {
			## dynamic dataset.
			my $DDSET = $g->{'%'}->{'ddataset'};
			my $DFORMAT = $g->{'%'}->{'dformat'};
			my $RESULTS = $self->dynamic_datasets($DDSET);
			foreach my $row (@{$RESULTS}) {
				$COLUMNS++;
				$g->{'%'}->{"dataset-$COLUMNS"} = sprintf("%s&t=%s",$row->[0],URI::Escape::XS::uri_escape($row->[1]));
				# $g->{'%'}->{"format-$COLUMNS"} = $DFORMAT;
				}
			}
		# print STDERR Dumper($g);

		my @datasets = ();	# 0=date,1=column1,2=column2
		my @series = ();
		foreach my $i (1..$COLUMNS) {
			## dataset-1, datase
			my $ds = "dataset-$i";
			next if (not defined $g->{'%'}->{$ds});
			my $DSN = $g->{'%'}->{$ds};
			# DSN: random?c=0&f=#&t=Random Numbers (testing)
			my ($dsid,$dsnparams) = &ZTOOLKIT::dsnparams($DSN);
			if ($dsnparams->{'c'}==0) { $dsnparams->{'c'} = 1; }

			## SANITY: now retrieve the results from the DSN, and store them into $RAW_DATA
			my %RAW_DATA = ();
			$g->{"raw-$i"} = \%RAW_DATA;	# for debugging

			my $results = $self->get_data($DSN,$startyyyymmdd,$stopyyyymmdd);
			# print STDERR Dumper($results);
			foreach my $line (@{$results}) {
				my $summarykey = $dtlookup->{ $line->[0] };
				push @{$RAW_DATA{$summarykey}}, $line->[ $dsnparams->{'c'} ];
				}

			# print STDERR Dumper(\%RAW_DATA);

			## SANITY: at this point %RAW_DATA is a hash, keyed by $summarytype (ex: Jan), and an arrayref containing set of data point matching that summary as the value
			##			  $grpby_sequence is an arrayref containing a list of keys (ex: Jan, Feb, Mar) in the proper sorted order.
			my $val = 0;
			# my $format = $g->{'%'}->{"format-$i"};
			my $format = $dsnparams->{'fmt'};
			my @RESULT_DATA = ();
			foreach my $summarykey (@{$grpby_sequence}) {
				my $sum = 0;
				my $min = undef;
				my $max = undef;
				my $count = 0;
				foreach my $v (@{$RAW_DATA{$summarykey}}) {
					$count++;
					$sum += $v;
					if ((not defined $min) || ($v<$min)) { $min = $v; }
					if ((not defined $max) || ($v<$max)) { $max = $v; }
					}
				if ($format eq 'sum') { $val = $sum; }
				elsif ($format eq 'min') { $val = $min; }
				elsif ($format eq 'max') { $val = $max; }
				elsif ($format eq 'avg') { 
					if ($count==0) { $val = 0; }
					else { $val = int($sum/$count); }
					}

				## finally, if there is a format we need to apply eq '#' or '$' then lets do that
				if ($dsnparams->{'ctype'} eq '$') { $val = int($val/100); }	# highcharts crashes on decimals
				elsif ($dsnparams->{'ctype'} eq '#') { $val = int($val); }

				push @RESULT_DATA, $val;
				}

			my $title = $dsnparams->{'t'};
			if ($format ne 'sum') {
				## sum is pretty standard.. so we don't do the format: in the title
				$title = sprintf("%s: %s",$format,$dsnparams->{'t'});
				}
			if (scalar(@RESULT_DATA)==1) {
				## one value, must be a pie chart.
				if ($title =~ /\#/) { $title =~ s/\#/%d/; $title = sprintf($title,$RESULT_DATA[0]); }
				if ($title =~ /\$/) { $title =~ s/\$/\$%d/; $title = sprintf($title,$RESULT_DATA[0]); }
				}
			push @series, { 'name'=>$title, 'data'=>\@RESULT_DATA };
			}


#		open F, ">/tmp/results.$UUID";
#		print F Dumper($g);
#		print F Dumper(\@series);

		my $graphtype = $g->{'GRAPH'};
		if ($graphtype eq 'donut') { $graphtype = 'pie'; }
		if ($graphtype eq 'donut') {
		#	$graphtype = 'pie';
		#	my $newseries = { 'type'=>'pie', name=>'XYZ', data=>[] };
		#	foreach my $s (@series) {
		#		push @{$newseries->{'data'}}, [ $s->{'name'}, @{$s->{'data'}} ];
		#		}
		#	print STDERR Dumper(\@series,[$newseries]);
		#	@series = ( $newseries );
			}
		elsif ($graphtype eq 'pie') {
			## restructure the data from series
			## [ { name=>"name1", data=>[ val1a,val1b ] }], [ { name=>"name2", data=>[ val2a,val2b ] }]
			## into:
			## [ { name=>"", data=>[ [ 'name1',val1a,val1b ], [ 'name2',val2a,val2b ] } ]
			my $newseries = { 'type'=>'pie', name=>'XYZ', data=>[] };
			foreach my $s (@series) {
				# $s->{'name'} = 'bob';
				push @{$newseries->{'data'}}, [ $s->{'name'}, @{$s->{'data'}} ];
				# push @{$newseries->{'data'}}, [ @{$s->{'data'}} ];
				}
			# print STDERR Dumper(\@series,[$newseries]);
			@series = ( $newseries );
			}

		if (0) {
			## a simple test dataset.
			@series = (
				{ "name"=>'Jane',"data"=>[1, 0, 4, 3] },
				{ "name"=>'John',"data"=>[5, 6, 7, 5] }
         	);
			}


#		print F Dumper(\@series);
#		close F;
		my $CHART_DATA = {
			chart=>{
				renderTo=>"$containerid",
				# defaultSeriesType=>$graphtype,	 # bar, 
				#events=>{
				#	'load'=>"requestData",
				#	},
				borderWidth=>"1", 
				borderColor=>"#CCCCCC",
				borderRadius=>5,
				borderWidth=>"1",
#				width=>"$width"
				},
			credits=>{		
				enabled=>0,
				},
			title=>{
				text=>$g->{'TITLE'},
	      	style=>{
   	         color=> '#000000',
      	      fontSize=>'12px',		# wow, trailing; here broke ie.
       	    	fontWeight=> 'bold',
		         },
				},
			subtitle=>{
				text=>"$startyyyymmdd - $stopyyyymmdd",
				# style=>"",
				},
			xAxis=>{
				categories=>\@xAxis,
				title=>{
					# text=>"$g->{'%'}->{'period'} $startyyyymmdd - $stopyyyymmdd"
					text=>"",
					}
				},
			yAxis=>{
				# categories=>\@xAxis,
				title=>{
					# text=>"$g->{'%'}->{'period'} $startyyyymmdd - $stopyyyymmdd"
					text=>"",
					}
				},
			series=>\@series,
			};
		
	 	# stacking  : String  null
		# Whether to stack the values of each series on top of each other. Possible values are null to disable, "normal" to stack by value or "percent". Defaults to null.
		# Try it: Line, column, bar, area with "normal" stacking. Line, column, bar, area with "percent" stacking.
		# $CHART_DATA->{'plotOptions'}->{'column'}->{'stacking'} = 'normal';
		# $CHART_DATA->{'plotOptions'}->{'areaspline'}->{'stacking'} = 'percent';
		if ($graphtype eq 'bar') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'bar';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = undef;
			}
		elsif ($graphtype eq 'bar.stacked') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'bar';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'normal';
			}
		elsif ($graphtype eq 'bar.percent') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'bar';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'percent';
			# $CHART_DATA->{'chart'}->{'inverted'} = 0;
			# $CHART_DATA->{'chart'}->{'backgroundColor'} = '#FF0000';
			}
		elsif ($graphtype eq 'area') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'area';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = undef;
			}
		elsif ($graphtype eq 'area.stacked') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'area';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'normal';
			}
		elsif ($graphtype eq 'area.percent') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'area';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'percent';
			}
		elsif ($graphtype eq 'column') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'column';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = undef;
			}
		elsif ($graphtype eq 'column.stacked') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'column';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'normal';
			}
		elsif ($graphtype eq 'column.percent') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'column';
			$CHART_DATA->{'plotOptions'}->{'series'}->{'stacking'} = 'percent';
			}
		elsif ($graphtype eq 'line') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'line';
			}
		elsif ($graphtype eq 'areaspline') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'areaspline';
			}
		elsif ($graphtype eq 'pie') {
			$CHART_DATA->{'chart'}->{'defaultSeriesType'} = 'pie';
			#$CHART_DATA->{'plotOptions'}->{'pie'}->{'showInLegend'} = 1;
			#$CHART_DATA->{'plotOptions'}->{'pie'}->{'dataLabels'} = 0;
			## does not work:
			#$CHART_DATA->{'plotOptions'}->{'pie'}->{'rotation'} = 45;			
			}

		## now if we have any user-json, lets try that.
		if ($g->{'%'}->{'user-json'} ne '') {
			my $user_config = eval { JSON::XS::decode_json($g->{'%'}->{'user-json'}) };
			if (defined $user_config) {
				require Data::Merger;
				$CHART_DATA = Data::Merger::merger($user_config,$CHART_DATA);
				}
			#require Data::ModeMerge;
			#$CHART_DATA = Data::ModeMerge::mode_merge($CHART_DATA, $user_config, {allow_destroy_hash=>0});
			}

		# print STDERR Dumper($CHART_DATA);
		
		my $JSON = JSON::XS::encode_json($CHART_DATA);
	return($JSON);
	}

1;