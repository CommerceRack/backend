package BATCHJOB::IMPORT::REWRITES;

use strict;
use URI::Escape::XS;
use lib "/backend/lib";
use DBINFO;
use DOMAIN::TOOLS;
use ZTOOLKIT;
use SEARCH;

sub import {
	my ($bj,$fieldsref,$lineref,$optionsref) = @_;

	my ($USERNAME,$MID,$LUSERNAME,$PRT) = ($bj->username(),$bj->mid(),$bj->lusername(),$bj->prt());
	
	use Data::Dumper;
	print STDERR Dumper($fieldsref,$optionsref);
	#print STDERR "$USERNAME: \n";
	#print STDERR Dumper($fieldsref);
	#print STDERR Dumper($lineref);
	my $linecount = 0;
	if (defined $optionsref->{'PRT'}) {
		$PRT = int($optionsref->{'PRT'});
		}

	# my $metaref = $bj->meta(); print Dumper($metaref);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	if ($optionsref->{'REWRITE_DESTRUCTIVE'}==1) {
		$bj->slog("Destroying existing URL maps for partition $PRT");
		my $pstmt = "/* BATCHJOB::IMPORT::REWRITES::import */ select DOMAIN from DOMAINS where MID=$MID /* $USERNAME:$PRT */ and PRT=$PRT";
		my $ref = $udbh->selectall_arrayref($pstmt);
		my @DOMAINS = ();
		foreach my $x (@{$ref}) { push @DOMAINS, $x->[0]; }
		$pstmt = "delete from DOMAINS_URL_MAP where MID=$MID /* $USERNAME */ and DOMAIN in ".&DBINFO::makeset($udbh,\@DOMAINS);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	my $rows_count = scalar(@{$lineref});
	my $rows_done = 0;

	# my ($LU) = LUSER->new($USERNAME,$LUSERNAME);

	foreach my $line ( @{$lineref} ) {
		my %DATA = ();
		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {
			$DATA{ uc($fieldsref->[$pos]) } = $line->[$pos];			
			$pos++;  # move to the next field that we should parse
			}
				
		my $TARGET_URL = $DATA{'%TARGETURL'};
		my $KEYWORDS = $DATA{'%KEYWORDS'};

		if ((defined $DATA{'%KEYWORDS'}) && ($DATA{'%KEYWORDS'} ne '')) {
			$KEYWORDS = $DATA{'%KEYWORDS'};
			}
		
		if ((defined $DATA{'%EXTRACT_KEYWORDS'}) && ($DATA{'%EXTRACT_KEYWORDS'} ne '') && ($KEYWORDS eq '')) {
			my $E = $DATA{'%EXTRACT_KEYWORDS'};
			my @KW =();
			
			if ($E =~ /^(.*?)\?(.*?)$/) {
				## url: /asdf.html?k1=v1&k2=v2
				## look and see if we've got a url with parameters on it..  then extract the v1 v2 as keywords from k1=v1&k2=v2
				my ($url,$params) = ($1,$2);
				$url =~ s/\.[A-Za-z]{3,4}$//s;	# remove .html,.htm,.etc
				@KW = split(/[\/\-]+/,$url);
				my $kvs = &ZTOOLKIT::parseparams($params);
				foreach my $k (keys %{$kvs}) { 
					next if ($kvs->{$k} eq '');
					push @KW, $kvs->{$k}; 
					}
				}
			elsif ($E =~ /^(.*?)$/) {
				## /something-else.html
				$E =~ s/\.[A-Za-z]{3,4}$//s;	# remove .html,.htm,.etc
				@KW = split(/[\/\-]+/,$E);
				}
			# print Dumper($E,\@KW);
			$KEYWORDS = join(' ',@KW);
			}

		if (($TARGET_URL eq '') && ($KEYWORDS ne '')) {
			my ($pids) = &SEARCH::search($USERNAME,
				'PRT'=>$PRT,
				'KEYWORDS'=>$KEYWORDS,
				'CATALOG'=>$optionsref->{'CATALOG'},
				);
			print 'PIDS: '.Dumper($pids);
			
			if ((not defined $pids) || (scalar(@{$pids})==0)) {
				## zero results goes to homepage
				$TARGET_URL = '/';
				}
			elsif (scalar(@{$pids})==1) {
				## single results 
				$TARGET_URL = '/product/'.$pids->[0].'?keywords='.URI::Escape::XS::uri_escape($DATA{'%KEYWORDS'});
				}
			else {
				$TARGET_URL = '/search.cgis?'.&ZTOOLKIT::buildparams({
					'catalog'=>$optionsref->{'CATALOG'},
					'keywords'=>$DATA{'%KEYWORDS'}
					});
				}
			print STDERR "TARGET_URL: $TARGET_URL (KEYWORDS: $KEYWORDS)\n";
			}

		#+-----------+--------------+------+-----+---------------------+----------------+
		#| Field     | Type         | Null | Key | Default             | Extra          |
		#+-----------+--------------+------+-----+---------------------+----------------+
		#| ID        | int(11)      | NO   | PRI | NULL                | auto_increment |
		#| USERNAME  | varchar(20)  | NO   |     | NULL                |                |
		#| MID       | int(11)      | NO   | MUL | 0                   |                |
		#| DOMAIN    | varchar(50)  | NO   |     | NULL                |                |
		#| PATH      | varchar(100) | NO   |     | NULL                |                |
		#| TARGETURL | varchar(200) | NO   |     | NULL                |                |
		#| CREATED   | datetime     | YES  |     | 0000-00-00 00:00:00 |                |
		#+-----------+--------------+------+-----+---------------------+----------------+
		#7 rows in set (0.00 sec)
		&DBINFO::insert($udbh,'DOMAINS_URL_MAP',{
			'USERNAME'=>$USERNAME,
			'MID'=>$MID,
			'DOMAIN'=>$DATA{'%DOMAIN'},
			'PATH'=>$DATA{'%PATH'},
			'TARGETURL'=>$TARGET_URL,
			'*CREATED'=>'now()',
			},update=>1,key=>['MID','DOMAIN','PATH']);

		if (($rows_done++%5)==0) {
			$bj->progress($rows_done,$rows_count,"Updated Maps");
			}
		$bj->slog("Update $rows_done: $DATA{'%DOMAIN'} $DATA{'%PATH'}");
		}

	&DBINFO::db_user_close();
	};


1;
__DATA__





1;
