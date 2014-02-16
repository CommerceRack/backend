package GTOOLSUI;

use strict;
use CGI;
use Data::Dumper;
use Storable;
use utf8 qw();
use Encode qw();
use strict;
use JSON::Syck;
use JSON::XS;
use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;
require NAVCAT;
require NAVCAT::CHOOSER;
use lib "/backend/lib";
use strict;
require ZOOVY;
require ZWEBSITE;
require LUSER;
require SITE;
require SITE::EMAILS;

no warnings 'once'; # Keeps perl from bitching about variables used only once.
use lib "/backend/lib";
require TOXML::UTIL;
require TOXML::COMPILE;
require ZOOVY;
require ZWEBSITE;
require LUSER;
require SITE;
use lib "/backend/lib"; 
use Storable;
require ZWEBSITE;	
require CART2;
require LUSER;
use lib "/backend/lib";
require SITE;
require ZWEBSITE;
require PAGE;
require ZTOOLKIT;
require NAVCAT;
require TOXML;
require TOXML::RENDER;
require TOXML::CHOOSER;
require LUSER;
require DOMAIN::TOOLS;
require PRODUCT;
use strict;
use URI::Escape;
use Data::Dumper;
require PRODUCT;
require Data::Dumper;
require strict;
require SITE;
require ZWEBSITE;
require TOXML;
require TOXML::UTIL;
require TOXML::COMPILE;
require DOMAIN::TOOLS;
require DOMAIN;
require SYNDICATION;
require ZTOOLKIT::SECUREKEY;
require BATCHJOB;
require LISTING::MSGS;
use File::Slurp;
	
require SEARCH;
require ZTOOLKIT;
require PRODUCT::FLEXEDIT;
require PAGE;
require PROJECT;


%GTOOLSUI::PATHS = (
	'/biz/vstore/toxml/index.cgi'=>[ '/httpd/htdocs/biz/vstore/toxml', \&GTOOLSUI::toxml ],
  	'/biz/vstore/advwebsite/index.cgi'=>[ '/httpd/htdocs/biz/vstore/advwebsite', \&GTOOLSUI::advwebsite, ],
  	'/biz/vstore/checkout/index.cgi'=>[ '/httpd/htdocs/biz/vstore/advwebsite', \&GTOOLSUI::advwebsite, ],
  	'/biz/vstore/builder/index.cgi'=>[ '/httpd/htdocs/biz/vstore/builder', \&GTOOLSUI::builder, ],
  	'/biz/vstore/builder/details.cgi'=>[ '/httpd/htdocs/biz/vstore/builder', \&GTOOLSUI::builder_details, ],
#	'/biz/vstore/navcats/index.cgi'=>[ '/httpd/htdocs/biz/vstore/navcats', \&GTOOLSUI::navcats, ],
#	'/biz/setup/navcats/index.cgi'=>[ '/httpd/htdocs/biz/vstore/navcats', \&GTOOLSUI::navcats, ],
  	'/biz/vstore/builder/emails/index.cgi'=>[ '/httpd/htdocs/biz/vstore/builder/emails', \&GTOOLSUI::builder_emails, ],
  	'/biz/vstore/builder/themes/index.cgi'=>[ '/httpd/htdocs/biz/vstore/builder/themes', \&GTOOLSUI::builder_themes, ],
  	'/biz/vstore/password/index.cgi'=>[ '/httpd/htdocs/biz/vstore/password', \&GTOOLSUI::password, ],
  	'/biz/setup/password/index.cgi'=>[ '/httpd/htdocs/biz/vstore/password', \&GTOOLSUI::password, ],
#  '/biz/vstore/builder/htmlpop.cgi'=>\&GTOOLSUI::htmlpop,
 	'/biz/vstore/billing/index.cgi'=>[ '/httpd/htdocs/biz/vstore/billing', \&GTOOLSUI::billing, ],
  	'/biz/vstore/analytics/index.cgi'=>[ '/httpd/htdocs/biz/vstore/analytics', \&GTOOLSUI::analytics, ],
  	'/biz/vstore/plugins/index.cgi'=>[ '/httpd/htdocs/biz/vstore/plugins', \&GTOOLSUI::analytics, ],
  	'/biz/vstore/search/index.cgi'=>[ '/httpd/htdocs/biz/vstore/search', \&GTOOLSUI::search, ],
	);


sub billing {
	return(html=>"Offline for upgrades");
	}


##
##
##
sub transmogrify {
	my ($JSONAPI,$uri,$vars) = @_;

	%GTOOLSUI::TAG = ();		## always initialize this.
	%GTOOLSUI::JSON = ();

	my $path = $uri;
	if ($uri =~ /^(.*?)\?(.*?)$/) { 
		$path = $1; 
		my $morevars = &ZTOOLKIT::parseparams($2); 
		foreach my $k (keys %{$morevars}) { 
			next unless (ref($k) eq '');	## not sure how this would happen.. but wtf!?
			$vars->{$morevars} = $morevars->{$k}; 
			}
		}
	
	my %R = ();

	if (not defined $GTOOLSUI::PATHS{$path}) {
		&JSONAPI::set_error(\%R,'iseerr',1983,sprintf("GTOOLSUI::PATHS{ $path } ..  is invalid/undefined"));
		}
	else {
		my ($BASEDIR,$FUNCTION) = @{$GTOOLSUI::PATHS{$path}};

		eval { %R = $FUNCTION->($JSONAPI,$vars); } ;

		$R{'__BASEDIR__'} = $BASEDIR;
		$R{'%vars'} = $vars;

		if ($@) {
			&JSONAPI::set_error(\%R,'iseerr',1984,sprintf("GTOOLSUI::$path got $@"));
			}
		else {
			$GTOOLSUI::TAG{'<!-- USERNAME -->'} = $JSONAPI->username();
			$GTOOLSUI::TAG{'<!-- LUSER -->'} = $JSONAPI->luser();
			$GTOOLSUI::TAG{'<!-- PRT -->'} = int($JSONAPI->prt());

			## secret header that turns on json responses.
			if (my $file = $R{'file'}) {
			 ## use Data::Dumper; print STDERR Dumper(ref($file),$file); die();

				if (substr($file,0,2) eq '_/') {
					## load from shared path
					$file = "/httpd/static/templates/".substr($file,2);
					}
				elsif (-f "$BASEDIR/templates/$file") { 
					$file = "$BASEDIR/templates/$file";
					}
				else { 
					&JSONAPI::set_error(\%R,'iseerr',1985,sprintf("GTOOLSUI::$path could not open \"$BASEDIR/templates/$file\""));
					$file = ''; 
					}
				
				if ($file) {
					open F, "<$file";
					$/ = undef; 
					$R{'html'} = <F>; 
					close F; 
					$/ = "\n";
					}
				else {
					}
				}

			if (defined $R{'bc'}) {
				foreach my $bc (@{$R{'bc'}}) {
					next if (not defined $bc->{'link'});
					$bc->{'link'} = &GTOOLSUI::link_fixup($bc->{'link'});
					}
				}
	
			if (defined $R{'tabs'}) {
				foreach my $tab (@{$R{'tabs'}}) {
					next if (not defined $tab->{'link'});
					$tab->{'link'} = &GTOOLSUI::link_fixup($tab->{'link'});
					}
				$R{'navtabs'} = $R{'tabs'};
				delete $R{'tabs'};
				}
	
			$GTOOLSUI::TAG{'<!-- TICKETS_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- SETUP_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- PRODUCT_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- ORDER_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- REPORT_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- UTILITIES_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- NO_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- HELP_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- SUPPORT_TAB -->'} = '';
			$GTOOLSUI::TAG{'<!-- SITES_TAB -->'} = '';
			$R{'html'} =~ s/(\<\!\-\- ([A-Z0-9\.\!\:\_\-]+) \-\-\>)/{((defined $GTOOLSUI::TAG{$1})?$GTOOLSUI::TAG{$1}:'')}/oegis;
			$R{'html'} = &ZTOOLKIT::stripUnicode($R{'html'});
			}

		if (not &JSONAPI::hadError(\%R)) {
			## success!
			}
		}

	return(\%R);
	}



sub password {
	my ($JSONAPI,$cgiv) = @_;
   $ZOOVY::cgiv = $cgiv;
   my ($LU) = $JSONAPI->LU();

	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	my ($VERB) = $ZOOVY::cgiv->{'VERB'};
	if ($VERB eq '') { $VERB = 'EDIT'; }
	print STDERR "VERB: $VERB\n";

	my @MSGS = ();	
	my $ACTION = $cgiv->{'ACTION'};

	# set the username
	$GTOOLSUI::TAG{"<!-- USERNAME -->"} = $USERNAME;
	$GTOOLSUI::TAG{'<!-- LUSER -->'} = ($LUSERNAME ne '')?'*'.$LUSERNAME:'';

	# loads the template
	my $template_file = "index.shtml";

	if ($ACTION eq 'SAVE_PASSWORD') {
		# gets the username
		my $OLDPASSWD = $cgiv->{'OLDPASSWORD'};
		my $LOGIN = $USERNAME . (($LUSERNAME eq '')?'':'*'.$LUSERNAME);
	
		# gets the new password for the USER
		my $NEWPASSWD = $cgiv->{'NEWPASSWORD'};
		my $NEWPASSWD2 = $cgiv->{'NEWPASSWORD1'};
	
		# my ($LU) = LUSER->new($USERNAME,$LUSERNAME);
		my $ERROR = undef;
		if (not $LU->passmatches($OLDPASSWD)) {
			#if there is any error displayed the error message
			$ERROR = "Old password does not match the one in our database.<br>";
			}
		elsif (my $REASON = &ZTOOLKIT::is_bad_password($NEWPASSWD)) {
			$ERROR = "Please choose another password: $REASON";
			}
		elsif ($NEWPASSWD ne $NEWPASSWD2) {
			# checks to make sure that both new passwords match each other
			# if new passwords does not match display an error
			$ERROR = "The new password does not match the other new one<br>";
			}
		else {
			# if it has passed both possible errors update their password
			$LU->set_password($NEWPASSWD);
			# load success page saying that password has been sucessful updated.
			}
	
		if (defined $ERROR) {	
			push @MSGS, "ERROR|+$ERROR";
			}
		else {
			push @MSGS, "SUCCESS|+Password updated";
			}
	
		$LU = undef;
		}

	print STDERR "FILE: $template_file\n";

	return(
		'title'=>'Setup : Change Password',
		'file'=>$template_file,
		'header'=>'1',
		'help'=>'#50677',
		'tabs'=>[],
		'msgs'=>\@MSGS,
		'bc'=>[
			{ name=>'Setup',link=>'','target'=>'_top', },
			{ name=>'Change Password',link=>'/biz/setup/password/index.cgi','target'=>'_top', },
			],
		);
	}


sub builder_emails {
	my ($JSONAPI,$cgiv) = @_;
   $ZOOVY::cgiv = $cgiv;
   my ($LU) = $JSONAPI->LU();

	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	my ($VERB) = $ZOOVY::cgiv->{'VERB'};
	if ($VERB eq '') { $VERB = 'EDIT'; }
	print STDERR "VERB: $VERB\n";
	
	my ($NS) = $ZOOVY::cgiv->{'NS'};
	$GTOOLSUI::TAG{'<!-- NS -->'} = $NS;
	my @TABS = ();
	my @MSGS = ();

	my $template_file = '';

	my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT,'DOMAIN'=>$LU->domainname());
	my ($SE) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE,RAW=>1);

	if ($VERB eq 'CONFIG') {
		}

	if ($VERB eq 'MSGNUKE') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		$SE->save($MSGID,"NUKE"=>1);
		push @MSGS, "SUCCESS|+Deleted message $MSGID";
		$VERB = '';	
		}

	##
	##
	##	
	if ($VERB eq 'MSGTEST') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		my ($err) = $SE->send($MSGID,TEST=>1,TO=>$ZOOVY::cgiv->{'MSGFROM'});
		$VERB = 'MSGEDIT';
	
		if ($err) {
			my $errmsg = $SITE::EMAILS::ERRORS{$err};
			push @MSGS, "ERROR|+$errmsg";
			}
		else {
			push @MSGS, "SUCCESS|+Successfully sent test email.";
			}
		}

	##
	##	
	##
	if ($VERB eq 'MSGSAVE') {
		## 
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};

		my %options = ();
		$options{'SUBJECT'} = $ZOOVY::cgiv->{'MSGSUBJECT'};
		$options{'BODY'} = $ZOOVY::cgiv->{'MSGBODY'};
		if (defined $ZOOVY::cgiv->{'MSGTYPE'}) {
			$options{'TYPE'} = $ZOOVY::cgiv->{'MSGTYPE'};
			}
		if (defined $ZOOVY::cgiv->{'MSGBCC'}) {
			$options{'BCC'} = $ZOOVY::cgiv->{'MSGBCC'};
			}
		if (defined $ZOOVY::cgiv->{'MSGFROM'}) {
			$options{'FROM'} = $ZOOVY::cgiv->{'MSGFROM'};
			}
	
		$options{'FORMAT'} = 'HTML';
		if (defined $ZOOVY::cgiv->{'MSGFORMAT'}) {
			$options{'FORMAT'} = $ZOOVY::cgiv->{'MSGFORMAT'};
			}
		
		push @MSGS, "SUCCESS|Successfully saved.";
		
		$SE->save($MSGID, %options);
		$VERB = 'MSGEDIT';
		}
	
	##
	##
	##
	if ($VERB eq 'MSGEDIT') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		my $msgref = $SE->getref($MSGID);
		
		$GTOOLSUI::TAG{'<!-- MSGTYPE -->'} = $msgref->{'MSGTYPE'};
		$GTOOLSUI::TAG{'<!-- MSGID -->'} = uc($MSGID);
		$GTOOLSUI::TAG{'<!-- MSGSUBJECT -->'} = &ZOOVY::incode($msgref->{'MSGSUBJECT'});
	
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_HTML -->'} = ($msgref->{'MSGFORMAT'} eq 'HTML')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_WIKI -->'} = ($msgref->{'MSGFORMAT'} eq 'WIKI')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_TEXT -->'} = ($msgref->{'MSGFORMAT'} eq 'TEXT')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_DONOTSEND -->'} = ($msgref->{'MSGFORMAT'} eq 'DONOTSEND')?'checked':'';
	
		$GTOOLSUI::TAG{'<!-- MSGBODY -->'} = &ZOOVY::incode($msgref->{'MSGBODY'});
		$GTOOLSUI::TAG{'<!-- MSGFROM -->'} = &ZOOVY::incode($msgref->{'MSGFROM'});
		$GTOOLSUI::TAG{'<!-- MSGBCC -->'} = &ZOOVY::incode($msgref->{'MSGBCC'});
		$GTOOLSUI::TAG{'<!-- CREATED -->'} = &ZTOOLKIT::pretty_date($msgref->{'CREATED_GMT'},1);
	
		foreach my $mline (@SITE::EMAILS::MACRO_HELP) {
			my $show = 0;
			if ($mline->[0] eq $msgref->{'MSGTYPE'}) { $show |= 1; }
			elsif (($msgref->{'MSGTYPE'} eq 'TICKET') && ($mline->[0] eq 'CUSTOMER')) { $show |= 1; }
			elsif (($msgref->{'MSGTYPE'} eq 'TICKET') && ($mline->[0] eq 'ORDER')) { $show |= 2; } # 2 = selective availability
	
			if ($show) {
			$GTOOLSUI::TAG{'<!-- MACROHELP -->'} .= 
				sprintf(q~<tr>
				<td class="av" valign="top">%s</td>
				<td class="av" valign="top">%s%s</td>
				</tr>~,
				&ZOOVY::incode($mline->[1]), 
				$mline->[2],
				((($show&2)==2)?'<div class="hint">Note: will only appear when properly associated.</div>':'')
				 );
				}
			}
	
		$template_file = 'msgedit.shtml';	
		}
	
	##
	##
	##
	if ($VERB eq 'EDIT') {
		$template_file = 'edit.shtml';
	
		my ($SE) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE,RAW=>1);
		my $result = $SE->available("");	
		foreach my $TYPE ('ORDER','ACCOUNT','PRODUCT','TICKET') {
			my $c = '';
			my $r = 0;
			my %MSGIDS = ();
			foreach my $msgref (@{$result}) {
				next if ($TYPE ne $msgref->{'MSGTYPE'});
				$MSGIDS{ $msgref->{'MSGID'} } = $msgref;
				}
	
			## we sort by MSGID
			foreach my $k (sort keys %MSGIDS) {
				my $msgref = $MSGIDS{$k};
				my $title = "SUBJECT: $msgref->{'MSGSUBJECT'}";
				if ($msgref->{'MSGTITLE'} ne '') { $title = "TITLE: $msgref->{'MSGTITLE'}"; }
	
				if (not defined $msgref->{'MSGFORMAT'}) { $msgref->{'MSGFORMAT'} = 'HTML'; }
	
				$r = ($r eq 'r0')?'r1':'r0';
				$c .= "<tr class='$r'>";
				$c .= "<td width='50px'><input type='button' class='button' value=' Edit ' onClick=\"navigateTo('/biz/vstore/builder/emails/index.cgi?NS=$NS&VERB=MSGEDIT&MSGID=$msgref->{'MSGID'}');\"></td>";
				$c .= "<td width='100px'>".&ZOOVY::incode($msgref->{'MSGID'})."</td>";
				$c .= "<td>".&ZOOVY::incode($title)."</td>";
				if (not defined $msgref->{'CREATED_GMT'}) { $msgref->{'CREATED_GMT'} = 0; }
				$c .= "<td width='100px'>".&ZTOOLKIT::pretty_date($msgref->{'CREATED_GMT'})."</td>";
				$c .= "<td width='100px'>".$msgref->{'MSGFORMAT'}."</td>";
				$c .= "</tr>";
				}
			$GTOOLSUI::TAG{"<!-- $TYPE -->"} .= $c;
			}
		# $GTOOLSUI::TAG{'<!-- ORDER -->'} = Dumper($result);
	
		}
	
	if ($VERB eq 'ADD') {
		$GTOOLSUI::TAG{'<!-- NS -->'} = $NS;
		$template_file = 'add.shtml';
		}
	
	
	#push @TABS, { name=>'Config', link=>"/biz/vstore/builder/emails/index.cgi?VERB=CONFIG", selected=>(($VERB eq 'SELECT')?1:0) };
	push @TABS, { name=>'Select', link=>"/biz/vstore/builder/themes/index.cgi?SUBTYPE=E&NS=$NS", selected=>(($VERB eq 'SELECT')?1:0) };
	push @TABS, { name=>'Edit', link=>"/biz/vstore/builder/emails/index.cgi?VERB=EDIT&NS=$NS", selected=>(($VERB eq 'EDIT')?1:0)  };
	push @TABS, { name=>'Add', link=>"/biz/vstore/builder/emails/index.cgi?VERB=ADD&NS=$NS", selected=>(($VERB eq 'ADD')?1:0)  };
	
	my @BC = ();
	push @BC, { name=>"Setup", link=>'/biz/vstore' };
	push @BC, { name=>"Builder", link=>'/biz/vstore/builder' };
	push @BC, { name=>"Emails", link=>'/biz/vstore/builder/emails' };
	
	return(file=>$template_file,header=>1,msgs=>\@MSGS,tabs=>\@TABS, bc=>\@BC);
	}




##
##
##

sub search {
	my ($JSONAPI,$cgiv) = @_;
	$ZOOVY::cgiv = $cgiv;

	my ($LU) = $JSONAPI->LU();	
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	if ($MID<=0) { exit; }
	
	my ($udbh) = DBINFO::db_user_connect($USERNAME);
	
	my $template_file = '';
	my $VERB = $ZOOVY::cgiv->{'ACTION'};
	
	my @MSGS = ();
	push @MSGS, "WARN|REMINDER: VStore end-of-life is January 1st, 2015.";
	
	if ($PRT>0) {
		push @MSGS, "WARN|Search catalogs (and logs) are shared across partitions - however it is possible to specify a different catalog per partition";
		}	
	
	if (($VERB eq 'GLOBAL') || ($VERB eq 'SAVE-GLOBAL')) {
		#if (not $LU->is_level(7)) {
		if ($LU->is_zoovy()) {
			push @MSGS, "WARN|Account level is insufficient (Zoovy support - you can save changes)";
			}
		elsif (not $LU->is_admin()) {
			push @MSGS, "WARN|Requires Administrative priviledges (you can view, but not save changes)";
			$VERB = 'GLOBAL-DENY';
			}
		#else {
		#	push @MSGS, "WARN|Account level is insufficient (you can view, but not save changes)";
		#	$VERB = 'GLOBAL-DENY';
		#	}
	   }
	
	
	
	if ($VERB eq 'SAVE-GLOBAL') {
		my $USER_PATH = &ZOOVY::resolve_userpath($USERNAME);
	
	
	
		unlink "$USER_PATH/elasticsearch-product-synonyms.txt";
		if ($ZOOVY::cgiv->{'SYNONYMS'}) {
			File::Slurp::write_file("$USER_PATH/elasticsearch-product-synonyms.txt",$ZOOVY::cgiv->{'SYNONYMS'});
			chmod 0666, "$USER_PATH/elasticsearch-product-synonyms.txt";
			push @MSGS, "SUCCESS|Saved product synonyms (reindex-needed)";
			}
	
		unlink "$USER_PATH/elasticsearch-product-stopwords.txt";
		if ($ZOOVY::cgiv->{'STOPWORDS'}) {
			File::Slurp::write_file("$USER_PATH/elasticsearch-product-stopwords.txt",$ZOOVY::cgiv->{'STOPWORDS'});
			chmod 0666, "$USER_PATH/elasticsearch-product-stopwords.txt";
			push @MSGS, "SUCCESS|Saved product stopwords (reindex-needed)";
			}
	
		unlink "$USER_PATH/elasticsearch-product-charactermap.txt";
		if ($ZOOVY::cgiv->{'CHARACTERMAP'}) {
			my @LINES = ();
			my %DUPS = ();
			my $linecount = 0;
			foreach my $line (split(/[\n\r]+/,$ZOOVY::cgiv->{'CHARACTERMAP'})) {
				$linecount++;
				my ($k,$v) = split(/\=\>/,$line);
				$k =~ s/^[s]+//gs;
				$k =~ s/[s]+$//gs;
				if (not defined $DUPS{$k}) {
					push @LINES, $line;
					}
				else {
					push @MSGS, "WARN|Line[$linecount] \"$line\" was ignored because it was duplicated earlier.";
					$DUPS{$k}++;
					}
				}
			File::Slurp::write_file("$USER_PATH/elasticsearch-product-charactermap.txt",join("\n",@LINES));
			chmod 0666, "$USER_PATH/elasticsearch-product-charactermap.txt";
			push @MSGS, "SUCCESS|Saved product character map (reindex-needed)";
			}
	
		$VERB = 'GLOBAL';
		}
	
	
	if (($VERB eq 'GLOBAL') || ($VERB eq 'GLOBAL-DENY')) {
	#-rw-r--r--+  1 root   root       1376 May 19 16:02 elasticsearch-product-charactermap.txt
	#-rw-r--r--+  1 root   root        163 May 19 16:02 elasticsearch-product-stopwords.txt
	#-rw-r--r--+  1 root   root      14170 May 19 16:02 elasticsearch-product-synonyms.txt	
		my $USER_PATH = &ZOOVY::resolve_userpath($USERNAME);	
		if (-f "$USER_PATH/elasticsearch-product-synonyms.txt") {
			$GTOOLSUI::TAG{'<!-- SYNONYMS -->'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-synonyms.txt") ;
			}
		if (-f "$USER_PATH/elasticsearch-product-stopwords.txt") {
			$GTOOLSUI::TAG{'<!-- STOPWORDS -->'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-stopwords.txt") ;
			}
		if (-f "$USER_PATH/elasticsearch-product-charactermap.txt") {
			$GTOOLSUI::TAG{'<!-- CHARACTERMAP -->'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-charactermap.txt") ;
			}
	
		require PRODUCT::FLEXEDIT;
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
		my @FIELDS = ();
		if (defined $gref->{'@flexedit'}) {
			foreach my $set (@{$gref->{'@flexedit'}}) {
				next unless (defined $set->{'index'});
				if (defined $PRODUCT::FLEXEDIT::fields{$set->{'id'}}) {
					## copy custom fields into global.bin ex: type, options, etc.
					foreach my $k (keys %{$PRODUCT::FLEXEDIT::fields{$set->{'id'}}}) {
						next if (defined $set->{$k});
						$set->{$k} = $PRODUCT::FLEXEDIT::fields{$set->{'id'}}->{$k};
						}
					}
				push @FIELDS, $set;
				}
			}
	
		if (scalar(@FIELDS)==0) {
			$GTOOLSUI::TAG{'<!-- PRODUCT_INDEXED_ATTRIBUTES -->'} = "<tr><td><i>None</td></tr>\n";
			}
		else {
		   $GTOOLSUI::TAG{'<!-- PRODUCT_INDEXED_ATTRIBUTES -->'} .= "<tr><td><b>ZOOVY TYPE</b></td><td><b>FIELD ID</b></td><td><b>ELASTIC NAME</b></td></tr>";
			foreach my $set (@FIELDS) {	
				$GTOOLSUI::TAG{'<!-- PRODUCT_INDEXED_ATTRIBUTES -->'} .= "<tr><td>$set->{'type'}</td><td>$set->{'id'}</td><td>$set->{'index'}</td></tr>\n";
				}
			}
	
	
		$template_file = 'global.shtml';
		}
	
	
	
	if ($VERB eq 'ADD') {
		my @ERRORS = ();
		my $CATALOG = uc($ZOOVY::cgiv->{'CATALOG'});
		# my $ATTRIBS = lc($ZOOVY::cgiv->{'FULLTEXT_ATTRIBS'});
		my $ATTRIBS = '';
	
		foreach my $id ('SUBSTRING','FINDER','COMMON') {
			if ($CATALOG eq $id) { push @ERRORS, "catalog:$id is reserved and cannot be used."; }
			}
	
		my @ATTRIBS = ();
		my ($fieldsref) = PRODUCT::FLEXEDIT::elastic_fields($USERNAME);
		foreach my $id ('id','tags','options','pogs') {
			if (defined $ZOOVY::cgiv->{"field:$id"}) {
				push @ATTRIBS, $id;
				}
			}
		foreach my $fieldset (@{$fieldsref}) {
			if (defined $ZOOVY::cgiv->{"field:$fieldset->{'id'}"}) {
				push @ATTRIBS, $fieldset->{'id'};
				}
			}
	
		if ($CATALOG eq '') { push @ERRORS, 'Sorry, you must specify a catalog name'; }
		if (scalar(@ATTRIBS)==0) {
	 		push @ERRORS, 'You must specify at least one valid (indexed) attribute'; 
			}
		else {
			$ATTRIBS = join(",",@ATTRIBS);
			}
	
		if (scalar(@ERRORS)>0) {
			foreach my $err (@ERRORS) { push @MSGS, "ERROR|$err"; }			
			}
		else {
			my $DICTDAYS = 0;
			&SEARCH::add_catalog($USERNAME,$CATALOG,$ATTRIBS);
			$LU->log("SETUP.SEARCH.ADD","CATALOG=$CATALOG ATTRIBS=$ATTRIBS",'INFO');
			}
		$VERB = '';
		}
	
	if ($VERB eq 'DELETE') {
		&SEARCH::del_catalog($USERNAME,$ZOOVY::cgiv->{'CATALOG'});
		$LU->log("SETUP.SEARCH.NUKE","Deleted catalog $ZOOVY::cgiv->{'CATALOG'}",'INFO');
		$VERB = '';
		}
	
	
	if ($VERB eq 'CREATE') {
		$template_file = 'create.shtml';
		}
	
	if ($VERB eq 'LOG-DELETE') {
		my $path = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
		my $file = $ZOOVY::cgiv->{'FILE'};
		$file =~ s/[\.]+/./g;	# remove multiple periods.
		$file =~ s/[\/\\]+//gs;	# remove all slashes
		unlink("$path/$file");
		$VERB = 'LOGS';
		}
	
	
	if ($VERB eq 'LOG-REPORT') {
		push @MSGS, "";
		## /biz/batch/index.cgi?VERB=NEW&GUID=$GUID&EXEC=REPORT&REPORT=SEARCHLOG_SUMMARY&.file=$file
		$VERB = 'LOGS';
		}
	
	
	
	
	if ($VERB eq 'LOGS') {
		##
		my $c = '';
		require BATCHJOB;
		my $GUID = &BATCHJOB::make_guid();
		my $path = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
		my $D = undef;
		opendir $D, $path;
	   my ($MEDIAHOST) = &ZOOVY::resolve_media_host($USERNAME);
		while ( my $file = readdir($D) ) {
			next if (substr($file,0,1) eq '.');
			my $CATALOG = '';
			if ($file =~ /^SEARCH-(.*?)\.(log|csv)$/) {
				$CATALOG = $1;
				if ($CATALOG eq '') { $CATALOG = 'N/A'; }
				my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path.'/'.$file);
				$c .= "<tr><td>$CATALOG</td><td>$file</td><td>".&ZTOOLKIT::pretty_date($mtime,1)."</td>";
				$c .= "<td nowrap>";
				$c .= "<a target=\"_blank\" href=\"//$MEDIAHOST/media/merchant/$USERNAME/$file\">[View]</a> ";
				$c .= " <a href=\"/biz/vstore/search/index.cgi?ACTION=LOG-DELETE&FILE=$file\">[Delete]</a>";
				$c .= " <a href=\"/biz/vstore/search/index.cgi?ACTION=LOG-REPORT&FILE=$file\">[Report]</a>";			
				$c .= " </td></tr>\n";
				}
			}
		closedir $D;
		if ($c eq '') { $c .= "<tr><td colspan=3><i>Sorry, no log files are available yet. Try performing a search on your website.</td></tr>"; }
		$GTOOLSUI::TAG{'<!-- LOG_FILES -->'} = $c;
		$template_file = 'logs.shtml';
		}
	
	
	
	if (($VERB eq 'RAWE') || ($VERB =~ /^RAWE-/)) {
		$template_file = 'rawe.shtml';
	
		$GTOOLSUI::TAG{'<!-- OUTPUT -->'} = '';
		
		my $QUERY = undef;
		my $PID = $ZOOVY::cgiv->{'PID'};
		my ($es) = &ZOOVY::getElasticSearch($USERNAME);		
		if ($VERB eq 'RAWE') {
			## not a "RUN"
			$es = undef;
			}
		elsif ($VERB eq 'RAWE-QUERY') {
			$QUERY = $ZOOVY::cgiv->{'QUERY'};
			if ($ZOOVY::cgiv->{'QUERY'} eq '') {
				push @MSGS, "WARN|No query specified"; 
				}
			}
	
		if (not defined $es) {
			## bad things alreadly happens.
	 		}
	   elsif ($VERB eq 'RAWE-SCHEMA-PID-LIVE') {
	      ## my ($schema) = &ELASTIC::rebuild_product_index($USERNAME,'schemaonly'=>1);
	      my ($path) = &ZOOVY::resolve_userpath($USERNAME);
	      open F, "<$path/public-index.dmp";
	      my $schema = undef;
	      while (<F>) { $schema .= $_; }
	      close F;
			$GTOOLSUI::TAG{'<!-- OUTPUT -->'} = "<pre><h2>LIVE Elastic Schema:</h2>$schema</pre>";      
	      }
	   elsif ($VERB eq 'RAWE-SCHEMA-PID-CONFIGURED') {
	      my ($schema) = &ELASTIC::rebuild_product_index($USERNAME,'schemaonly'=>1);
			$GTOOLSUI::TAG{'<!-- OUTPUT -->'} = "<pre><h2>CURRENT Elastic Schema:</h2>".Dumper($schema)."</pre>";      
	      }
		elsif ($VERB eq 'RAWE-QUERY') {
			use JSON::XS;
	
			my $Q = undef;
			my $results = undef;
			eval { $Q = JSON::XS::decode_json($QUERY); };
			if ($@) {
				push @MSGS, "ERROR|JSON Decode Error: $@"; 
				$Q = undef;
				}
			else {
				$Q->{'index'} = lc("$USERNAME.public");
				foreach my $k (keys %{$Q}) {
					if (substr($k,0,1) eq '_') { 
						push @MSGS, "INFO|+removed key '$k' because it started with an underscore and is not valid (just being helpful)";
						delete $Q->{$k};
						}
					}
				if ((not defined $Q->{'filter'}) && (not defined $Q->{'query'})) {
					push @MSGS, "WARN|+No 'filter' or 'query' was specified, so this probably won't work real well.";
					}
	
				## www.elasticsearch.org/guide/reference/query-dsl/term-query.html
				## filter should use:
				
				## query should use: 
				}
	
			## print STDERR Dumper($Q,\@MSGS);
	
			if ((defined $Q) && (defined $es)) {
			   eval { $results = $es->search(%{$Q}); };
				if ($@) {
					push @MSGS, "ERROR|Elastic Search Error:$@";
					}
				}
	
			$GTOOLSUI::TAG{'<!-- QUERY -->'} = $QUERY;
			$GTOOLSUI::TAG{'<!-- OUTPUT -->'} = "<pre><h2>Search Results:</h2>".Dumper($Q,$results)."</pre>";
			}
		elsif (($VERB eq 'RAWE-SHOWPID') || ($VERB eq 'RAWE-INDEXPID')) {
	
			if ($PID eq '') {
				push @MSGS, "ERROR|PID not specified";
				}
			elsif ($VERB eq 'RAWE-INDEXPID') {
				my ($P) = PRODUCT->new($USERNAME,$PID);
				if (not defined $P) {
					push @MSGS, "ERROR|Product '$PID' does not exist in product database";
					}
				else {
					push @MSGS, "SUCCESS|Product '$PID' was immediately indexed into elastic";
					&ELASTIC::add_products($USERNAME,[$P],'*es'=>$es);
					sleep(5);	# make them wait (avoids abuse, gives elastic a chance to catch up)
					}
				}
	
			if ($PID ne '') {
		     	my $result = undef;
	         eval { $result = $es->get(index =>lc("$USERNAME.public"),'type'=>'product','id'=>$PID); };
	         if ($@) {
	            push @MSGS, "ERROR|Elastic retrieval error - $@";
	            }
				$GTOOLSUI::TAG{'<!-- OUTPUT -->'} = "<pre><h2>Product Document Get:</h2>".Dumper($result)."</pre>";
				}
			}
		else {
			push @MSGS, "ERROR|+Invalid VERB:$VERB";
			}
	
		$VERB = 'RAWE';
		}
	
	
	if ($VERB eq 'DEBUG') {
		$GTOOLSUI::TAG{'<!-- DEBUG_OUT -->'} = "<i>No debug output.</i>";
		}
	
	if ($VERB eq 'EXPLODE-DEBUG') {
		my $c = '';
		my $explode = $ZOOVY::cgiv->{'EXPLODE'};
		if ($explode eq '') { 
			$c = "<div class='error'>No sku/model # for explosion was passed</div>";
			}
		else {
			my $results = &SEARCH::explode($explode);
			$c .= "<b>Keyword explosion for $explode:</b><br>".$results;
			}
		
		$GTOOLSUI::TAG{'<!-- DEBUG_OUT -->'} = $c;
		$VERB = 'DEBUG';
		}
	
	
	##
	##
	if ($VERB eq 'DEBUG-RUN') {
		use Data::Dumper;
		my $log = '';
	
		my ($CATALOG) = $ZOOVY::cgiv->{'CATALOG'};
		my ($SEARCHFOR) = $ZOOVY::cgiv->{'SEARCHFOR'};
		my ($PID) = $ZOOVY::cgiv->{'PRODUCT'};
		$SEARCHFOR =~ s/^[\s]+//g; # strip leading whitespace
		$SEARCHFOR =~ s/[\s]+$//g;	# strip trailing whitespace
	
		$LU->set('setup.search.debug.catalog',$CATALOG);
		$LU->set('setup.search.debug.root',$ZOOVY::cgiv->{'SITE'});
		$LU->save();
	
		my ($xPRT,$ROOT) = split(/-/,$ZOOVY::cgiv->{'SITE'});
	
		if ($PID ne '') {
			$log .= "<tr><td valign=top>Debug Product: $PID</td></tr>";
			}
	
		my %params = (MODE=>'',KEYWORDS=>$SEARCHFOR,CATALOG=>$CATALOG,TRACEPID=>$PID,debug=>1,ROOT=>$ROOT,PRT=>$xPRT);
		my $ref = &ZTOOLKIT::parseparams($ZOOVY::cgiv->{'ELEMENT'});
		foreach my $k (keys %{$ref}) {
			$params{$k} = $ref->{$k};
			}
	
		my ($outref,$prodsref,$tracelog) = SEARCH::search($USERNAME,%params);
	
		foreach my $line (@{$tracelog}) {
			$log .= "<tr><td valign=top>$line</td></tr>";
			}
		
		$GTOOLSUI::TAG{'<!-- DEBUG_OUT -->'} = "Searching for: $SEARCHFOR<br><br>Element Parameters: ".Dumper(\%params)."<br><br>Trace Log:<br>".
		"<table>$log</table>".
		"<hr>Output:<br><pre>".Dumper(SHORT_RESULTS=>$outref)."</pre>";
	
		$VERB = 'DEBUG';
		}
	
	##
	##
	if ($VERB eq 'DEBUG') {
		my $catalogref = &SEARCH::list_catalogs($USERNAME);
		my $c = '';
	
		my $FOCUS_CATALOG = $ZOOVY::cgiv->{'CATALOG'};
		if (not defined $FOCUS_CATALOG) {
			$FOCUS_CATALOG = $LU->get('setup.search.debug.catalog');
			}
		my $FOCUS_SITE = $ZOOVY::cgiv->{'SITE'};
		if (not defined $FOCUS_SITE) {
			$FOCUS_SITE = $LU->get('setup.search.debug.root');
			}
	
		$c .= "<option></option>";
		foreach my $cat (keys %{$catalogref}) {
			my $hashref = $catalogref->{$cat};
			my $selected = ($FOCUS_CATALOG eq $hashref->{'CATALOG'})?'selected':'';
			$c .= "<option $selected value='$hashref->{'CATALOG'}'>$hashref->{'CATALOG'}</option>\n";
			}
		$c .= "<option value='FINDER'>FINDER (built-in)</option>\n";
		$c .= "<option value='COMMON'>COMMON (built-in)</option>\n";
		$c .= "<option value='SUBSTRING'>SUBSTRING (built-in)</option>\n";
		$GTOOLSUI::TAG{'<!-- CATALOGS -->'} = $c;
	
		$GTOOLSUI::TAG{'<!-- SEARCHFOR -->'} = &ZOOVY::incode($ZOOVY::cgiv->{'SEARCHFOR'});
		$GTOOLSUI::TAG{'<!-- ELEMENT -->'} = &ZOOVY::incode($ZOOVY::cgiv->{'ELEMENT'});
		
		$c = '';
		my $i = 0;
		require DOMAIN::TOOLS;
		foreach my $prt (@{&ZWEBSITE::list_partitions($USERNAME)}) {
			my ($prtinfo) = &ZWEBSITE::prtinfo($USERNAME,$i);
			#my ($PROFILE) = $prtinfo->{'profile'};
			#my ($root) = &ZOOVY::fetchmerchantns_attrib($USERNAME,$PROFILE,'zoovy:site_rootcat');
			#if ($root eq '') { $root = '.'; }
	#
	      my $root = '.';
			my $value = "$i-$root";
			my ($selected) = ($value eq $FOCUS_SITE)?'selected':'';
	
			$c .= "<option disabled></option>";
			$c .= "<option $selected value=\"$value\">PRT:$prt [root=$root]</option>";
	
			my @DOMAINS = &DOMAIN::TOOLS::domains($USERNAME,PRT=>$prt,DETAIL=>1);
			foreach my $dref (@DOMAINS) {
				## my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$dref->{'PROFILE'});
				## my $root = $nsref->{'zoovy:site_rootcat'};
				my $value = "$i-$root";
				my ($selected) = ($value eq $FOCUS_SITE)?'selected':'';
				$c .= "<option $selected value=\"$value\">- DOMAIN: $dref->{'DOMAIN'} [prt=$prt] [root=$root]</option>";
				}
	
	
			$i++;
			}
		$GTOOLSUI::TAG{'<!-- PARTITIONS -->'} = $c;
	
		
	
		$template_file = 'debug.shtml';
		}
	
	if ($VERB eq 'CONFIG-SAVE') {
		my ($CATALOG) = $ZOOVY::cgiv->{'CATALOG'};
		&DBINFO::insert($udbh,'SEARCH_CATALOGS',{
			'MID'=>$MID,
			'CATALOG'=>$CATALOG,
			'ATTRIBS'=>$ZOOVY::cgiv->{'ATTRIBS'},
			'ISOLATION_LEVEL'=>int($ZOOVY::cgiv->{'ISOLATION_LEVEL'}),
			'USE_EXACT'=>(defined $ZOOVY::cgiv->{'USE_EXACT'})?1:0,
			'USE_WORDSTEMS'=>(defined $ZOOVY::cgiv->{'USE_WORDSTEMS'})?1:0,
			'USE_INFLECTIONS'=>(defined $ZOOVY::cgiv->{'USE_INFLECTIONS'})?1:0,
			'USE_SOUNDEX'=>(defined $ZOOVY::cgiv->{'USE_SOUNDEX'})?1:0,
			'USE_ALLWORDS'=>(defined $ZOOVY::cgiv->{'USE_ALLWORDS'})?1:0,
			},key=>['MID','CATALOG'],debug=>1);
		$VERB = 'CONFIG';
		}
	
	##
	##
	##
	if ($VERB eq 'CONFIG') {
		$template_file = 'config.shtml';
		my ($CATALOG) = $ZOOVY::cgiv->{'CATALOG'};
		
		my ($ref) = &SEARCH::fetch_catalog($USERNAME,$CATALOG);
	
		my $i = 0;
		my @ERRORS = ();
		require PRODUCT::FLEXEDIT;
		foreach my $k (split(/[,\n\r]+/,$ref->{'ATTRIBS'})) {
			next if ($k eq '');
			$k =~ s/^[\s]+//g;
			$k =~ s/[\s]+$//g;
			if ($k eq 'id') {
				$i++;
				}
			elsif ($PRODUCT::FLEXEDIT::fields{ $k }) {
				$i++;
				}
			## amended code to enable 'user:' attributes to pass validation.
			## nick advised these attributes would be appearing a lot more in merchant global.bin files
			elsif (($k =~ /^$USERNAME\:/) || ($k =~ /^user\:/)) {
				$i++;
				}
			else {
				push @ERRORS, "<div><font color='red'>Unknown/Invalid attribute: $k</font></div>";
				}
			}
		if ($i==0) {
			push @ERRORS, "<div><font color='red'>No Attributes found.</font></div>";
			}
		$GTOOLSUI::TAG{'<!-- ATTRIBS_WARNING -->'} = join('',@ERRORS);
	
		$GTOOLSUI::TAG{'<!-- ATTRIBS -->'} = &ZOOVY::incode($ref->{'ATTRIBS'});
	
		$GTOOLSUI::TAG{'<!-- ISO_0 -->'} = ($ref->{'ISOLATION_LEVEL'}==0)?'checked':'';
		$GTOOLSUI::TAG{'<!-- ISO_5 -->'} = ($ref->{'ISOLATION_LEVEL'}==5)?'checked':'';
		$GTOOLSUI::TAG{'<!-- ISO_10 -->'} = ($ref->{'ISOLATION_LEVEL'}==10)?'checked':'';
	
		$GTOOLSUI::TAG{'<!-- USE_INFLECTIONS -->'} = ($ref->{'USE_INFLECTIONS'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- USE_WORDSTEMS -->'} = ($ref->{'USE_WORDSTEMS'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- USE_SOUNDEX -->'} = ($ref->{'USE_SOUNDEX'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- USE_EXACT -->'} = ($ref->{'USE_EXACT'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- USE_ALLWORDS -->'} = ($ref->{'USE_ALLWORDS'})?'checked':'';
	
		$GTOOLSUI::TAG{'<!-- CATALOG -->'} = $CATALOG;
		}
	
	
	if ($VERB eq '') { 
		my $catalogref = &SEARCH::list_catalogs($USERNAME);
		my $c = '';
		my $cat;
		my $lasttime;
		my $catalogcount = 0;
	
		my ($fieldsref) = PRODUCT::FLEXEDIT::elastic_fields($USERNAME);
		foreach my $ref (@{$fieldsref}) {
			$c .= "<tr><td><input type=\"checkbox\" name=\"field:$ref->{'id'}\"><td>$ref->{'id'}</td><td>$ref->{'index'}</td></tr>";
			}
		$GTOOLSUI::TAG{'<!-- INDEXED_FIELDS -->'} = $c;
	
		$c = '';
		my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		$catalogref->{'COMMON'} = { 
			'CATALOG'=>'COMMON',
			'FORMAT'=>'ELASTIC',
			'ATTRIBS'=>'** performs elastic search on common fields **',
			LASTINDEX=>0,
			DIRTY=>0
			};
	
		$GTOOLSUI::TAG{'<!-- SUBSTRING_NOT_AVAILABLE -->'} = '';
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
		if (defined $gref->{'%tuning'}) {
			## tuning parameters can alter behaviors here.
			if (defined $gref->{'%tuning'}->{'disable_substring'}) {
				delete $catalogref->{'SUBSTRING'};
				$GTOOLSUI::TAG{'<!-- SUBSTRING_NOT_AVAILABLE -->'} = '[NOT AVAILABLE]';
				}
			}
		
		require BATCHJOB;
		my ($GUID) = BATCHJOB::make_guid();
	
		foreach $cat (keys %{$catalogref}) {
			my $hashref = $catalogref->{$cat};
	
			$catalogcount++;
			my $row = "r".($catalogcount%2);
	
			$c .= "<tr>";
			$c .= "<td nowrap valign=top class='$row'>";
			$c .= "ID: $hashref->{'CATALOG'}<br>";
			# $c .= "TYPE: $hashref->{'FORMAT'}<br>";
			$c .= "</td>";
	
			
			if ($hashref->{'ID'} eq 'FINDER') {
				$c .= "<td valign=top class='$row'>product options</td>";
				}
			elsif ($hashref->{'ID'} eq 'SUBSTRING') {
				$c .= "<td valign=top class='$row'>product id, sku, product name</td>";
				}
			elsif ($hashref->{'ID'} eq 'COMMON') {
				$c .= "<td valign=top class='$row'>most commonly used fields (designed by zoovy)</td>";
				}
			else {
				$hashref->{'ATTRIBS'} =~ s/,[\s]*/, /g;
				$c .= "<td valign=top class='$row'>$hashref->{'ATTRIBS'}</td>";
				}
			$c .= "<td valign=top class='$row' nowrap>";
	
			$c .= '[<a href="/biz/vstore/search/index.cgi?ACTION=DELETE&CATALOG='.$hashref->{'CATALOG'}.'">DELETE</a>]<br>';
	
	
	#		$lasttime = &ZTOOLKIT::mysql_to_unixtime($hashref->{'LASTINDEX'});
	#		if ($hashref->{'FORMAT'} eq 'SUBSTRING') {
	#			## can't reset finders.
	#			}
	#		elsif ($hashref->{'FORMAT'} eq 'ELASTIC') {
	#			}
	#		else {
	#			if (int($lasttime) <= 0) {
	#				$lasttime = "Never";
	#				}
	#			else {
	#				$lasttime = &ZTOOLKIT::pretty_time_since($lasttime,time());
	#				}
	#			$c .= " [<a class='smlink' href=\"/biz/batch/index.cgi?VERB=ADD&GUID=$GUID&EXEC=UTILITY&APP=CATALOG_REBUILD&.format=$hashref->{'FORMAT'}&.catalog=$hashref->{'CATALOG'}\">RESET</a>]<br>";
	#			}
	#
	
			$c .= "</td>";
	
	#		if ($hashref->{'DIRTY'}>0) { $c .= "<td valign=top class='$row'>NOT-CURRENT</td>"; } else { $c .= "<td valign=top class='$row'>OKAY</td>"; }
	#		$c .= "<td valign=top class='$row'>$lasttime</td>"; 
	#		my %AR;
	#		my $file = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-$hashref->{'CATALOG'}.cdb";
	#		my $cdb = tie %AR, 'CDB_File', $file;
	#		my $keycount = -1;
	#		if (defined $cdb) {
	#			$keycount = scalar(keys %AR);
	#			$cdb = undef;
	#			untie(%AR);	
	#			}
	##		$c .= "<td valign=top class='$row'>".$keycount."</td>";
	#		if ($hashref->{'FORMAT'} ne 'FULLTEXT') { $c .= "<td valign=top class='$row'>N/A</td>"; }
	#		elsif ($hashref->{'FORMAT'} == -1) { $c .= "<td valign=top class='$row'>Disabled</td>"; }
	#		elsif ($hashref->{'FORMAT'} == 0) { $c .= "<td valign=top class='$row'>All Days</td>"; }
	#		else { $c .= "<td valign=top class='$row'>$hashref->{'DICTIONARY_DAYS'} days</td>"; }
	#		$c .= "</tr>";
			}
	
		if ($c ne '') {
			$c = qq~
			<tr class="zoovytableheader">
				<td>Name</td>
				<td>Attributes</td>
				<td>&nbsp;</td>
			</tr>~.$c;
			} 
		else {
			$c .= "<tr><td><i>No catalogs currently exist, create the default catalog first.</i></td></tr>";
			}
		$GTOOLSUI::TAG{'<!-- CATALOG_LIST -->'} = $c;
		$c = '';
	
		
	#	my $sogsref = &POGS::list_sogs($USERNAME);
	#	if (defined $sogsref) {
	#		foreach my $id (keys %{$sogsref}) {
	#			$c .= "<option value=\"$id\">[$id] ".$sogsref->{$id}."</option>\n";
	#			}
	#		}
	#	$GTOOLSUI::TAG{'<!-- AVAILABLE_SOGS -->'} = $c;
	#	$c = '';
	#
	#	$c = '';
		$template_file = 'index.shtml';
		}
	
	
	if ($VERB eq 'DENY') {
		$template_file = 'deny.shtml';
		}
	
	&DBINFO::db_user_close();
	
	
	my @TABS = ();
	push @TABS, { name=>"Catalogs", selected=>($VERB eq '')?1:0, link=>"/biz/vstore/search/index.cgi?ACTION="  };
	push @TABS, { name=>"Logs", selected=>($VERB eq 'LOGS')?1:0, link=>"/biz/vstore/search/index.cgi?ACTION=LOGS"  };
	push @TABS, { name=>"Catalog Debug", selected=>($VERB eq 'DEBUG')?1:0, link=>"/biz/vstore/search/index.cgi?ACTION=DEBUG"  };
	push @TABS, { name=>"Tuning", selected=>($VERB eq 'GLOBAL')?1:0, link=>"/biz/vstore/search/index.cgi?ACTION=GLOBAL" };
	push @TABS, { name=>"Elastic Raw", selected=>($VERB eq 'DEBUG')?1:0, link=>"/biz/vstore/search/index.cgi?ACTION=RAWE"  };
	
	
	return(
	   'title'=>'Setup : Advanced Site Search',
	   'file'=>$template_file,
	   'header'=>'1',
	   'help'=>'#50345',
		'jquery'=>1,
	   'tabs'=>\@TABS,
		'msgs'=>\@MSGS,
	   'bc'=>[
	      { name=>'Setup',link=>'/biz/vstore','target'=>'_top', },
	      { name=>'Advanced Site Search',link=>'/biz/vstore/search','target'=>'_top', },
	      ],
	   );
	
	}


sub analytics {
	my ($JSONAPI,$cgiv) = @_;
	$ZOOVY::cgiv = $cgiv;

	my ($LU) = $JSONAPI->LU();
	
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	if ($MID<=0) { exit; }
	
	
	my $GUID = &BATCHJOB::make_guid();
	$GTOOLSUI::TAG{'<!-- GUID -->'} = $GUID;
	
	$GTOOLSUI::TAG{'<!-- PRT -->'} = $PRT;
	my $template_file = 'index.shtml';
	
	my @TABS = (
		);
	my @BC = (
		{ name=>"Setup" },
		{ link=>'/biz/vstore/analytics/index.cgi',  name=>"Analytics &amp; Plugins" },
		);
	my @MSGS = ();
	push @MSGS, "WARN|REMINDER: VStore end-of-life is January 1st, 2015.";
	
	my $SO = undef;
	
	my $VERB = $ZOOVY::cgiv->{'VERB'};
	
	$::WARN_INSECURE_FOOTER_REFERENCE = "The string 'http:' appears in the footer javascript. This could be a reference to an insecure image/pixel/iframe. The footer is normally shown on checkout/secure pages and so an insecure reference could cause a security warning with IE 8. Please consider changing from http: to https: if possible.";
	$::WARN_INSECURE_CHKOUT_REFERENCE = "The string 'http:' appears in the checkout javascript. This could be a reference to an insecure image/pixel/iframe. The footer is normally shown on checkout/secure pages and so an insecure reference could cause a security warning with IE 8. Please consider changing from http: to https: if possible.";
	$::WARN_INSECURE_CHKOUT_REFERENCE = "The string 'http:' appears in the login javascript. This could be a reference to an insecure image/pixel/iframe. The footer is normally shown on checkout/secure pages and so an insecure reference could cause a security warning with IE 8. Please consider changing from http: to https: if possible.";
	
	my @WARNINGS = ();
	my $NSREF = undef;
	my $WEBDB = undef;
	$WEBDB = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my ($D) = DOMAIN->new($LU->username(),$LU->domainname());
	my ($NSREF) = $D->as_legacy_nsref();
	
	my $help = '51020';
	
	
	
	##
	## Google Analytics.
	##
	if ($VERB eq 'GOOGLETS-SAVE') {
		$NSREF->{'googlets:search_account_id'} = $ZOOVY::cgiv->{'search_account_id'};
		$NSREF->{'googlets:badge_code'} = $ZOOVY::cgiv->{'badge_code'};
		$NSREF->{'googlets:chkout_code'} = $ZOOVY::cgiv->{'chkout_code'};
	#	$NSREF->{'analytics:headjs'} = $ZOOVY::cgiv->{'head_code'};
	#	$NSREF->{'analytics:syndication'} = (defined $ZOOVY::cgiv->{'syndication'})?'GOOGLE':'';
	#	$NSREF->{'analytics:roi'} = 'GOOGLE';
	#	$NSREF->{'analytics:linker'} = (defined $ZOOVY::cgiv->{'linker'})?time():'';
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved GOOGLE TRUSTED STORES plugin code","SAVE");
		$VERB = 'GOOGLETS';
		}
	
	
	if ($VERB eq 'GOOGLETS') {
		$GTOOLSUI::TAG{'<!-- SEARCH_ACCOUNT_ID -->'} = $NSREF->{'googlets:search_account_id'};
		$GTOOLSUI::TAG{'<!-- BADGE_CODE -->'} = &ZOOVY::incode($NSREF->{'googlets:badge_code'});
		$GTOOLSUI::TAG{'<!-- CHKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'googlets:chkout_code'});
	#	$GTOOLSUI::TAG{'<!-- CHK_ROI -->'} = ($NSREF->{'analytics:roi'} eq 'GOOGLE')?'checked':'';
	#	$GTOOLSUI::TAG{'<!-- CHK_SYNDICATION -->'} = ($NSREF->{'analytics:syndication'} eq 'GOOGLE')?'checked':'';
	#	$GTOOLSUI::TAG{'<!-- CHK_LINKER -->'} = ($NSREF->{'analytics:linker'}>0)?'checked':'';
	#
	#	if ($GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} =~ /XXXXX/) {
	#		$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = qq~ <div class="error">Zoovy Marketing Services Google Analytics Code has not been customized and will not work.</div>~;
	#		}
	
	#	if ($NSREF->{'analytics:headjs'} =~ /urchin/) {
	#		push @WARNINGS, "Appears to have older 'urchin' version of the google code. Many zoovy features (such as Google Checkout) will not work.";
	#		}
	
	#	require DOMAIN::TOOLS;
	#	my ($DOMAIN) = &DOMAIN::TOOLS::domain_for_profile($USERNAME,$PROFILE);
	#	my $ztscode = '';
	#	open F, "<googlets.txt";
	#	$/ = undef; $ztscode = <F>; $/ = "\n";
	#	close F;
	#	require URI::Escape;
	#	$GTOOLSUI::TAG{'<!-- ZTSCODE -->'} = ZOOVY::incode($ztscode);
		
		$template_file = 'googlets.shtml';
		push @BC, { name=>'Google Trusted Stores' };
		}
	
	
	
	
	
	if ($VERB eq 'DECALS') {
		$GTOOLSUI::TAG{'<!-- WRAPPER -->'} = $NSREF->{'zoovy:site_wrapper'};
	
		require TOXML;	
	
		my ($t) = TOXML->new('WRAPPER',$NSREF->{'zoovy:site_wrapper'},USERNAME=>$USERNAME);
		my (@decals) = $t->findElements('DECAL');
		my $c = '';
		foreach my $d (@decals) {
			$c .= "<tr>";
			$c .= "<td width=100% class='zoovysub1header'>$d->{'PROMPT'}</td>";
			$c .= "</tr>";
			$c .= "<tr>";
			$c .= "<td>";
			$c .= "<div class='hint'>Max Height: $d->{'HEIGHT'} &nbsp;  Max Width: $d->{'WIDTH'}</div>";
			$c .= "</td>";
			$c .= "</tr>";
			}
		$GTOOLSUI::TAG{'<!-- DECALS -->'} = $c;
	
		$template_file = 'decals.shtml';
		}
	
	
	if ($VERB eq 'FACEBOOK-APP-SAVE') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		$webdb->{'facebook_appid'} = int($ZOOVY::cgiv->{'facebook_appid'});
		$webdb->{'facebook_secret'} = int($ZOOVY::cgiv->{'facebook_secret'});
		&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$PRT);
		if ($webdb->{'facebook_appid'} ne '') {
			push @MSGS, "SUCCESS|Set Facebook Application ID";
			}
		$VERB = 'FACEBOOK-APP';
		}
	
	if ($VERB eq 'FACEBOOK-APP') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		$GTOOLSUI::TAG{'<!-- FACEBOOK_APPID -->'} = $webdb->{'facebook_appid'};	
		$GTOOLSUI::TAG{'<!-- FACEBOOK_SECRET -->'} = $webdb->{'facebook_secret'};	
		$template_file = 'facebook-app.shtml';
		}
	
	
	##
	##
	##
	
	if ($VERB eq 'TWITTER-SAVE') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	
		$webdb->{'twitter'} = &ZTOOLKIT::buildparams({
			'access_token'=>$ZOOVY::cgiv->{'twitter:access_token'},
			'access_secret'=>$ZOOVY::cgiv->{'twitter:access_secret'},
			'consumer_key'=>$ZOOVY::cgiv->{'twitter:consumer_key'},
			'consumer_secret'=>$ZOOVY::cgiv->{'twitter:consumer_secret'},
			});
		&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$PRT);
	
		$NSREF->{'twitter:userid'} = $ZOOVY::cgiv->{'twitter:userid'};
		$D->from_legacy_nsref($NSREF); $D->save();
	
		push @MSGS, "SUCCESS|Saved Twitter Settings";
		$VERB = 'TWITTER';
		}
	
	if ($VERB eq 'TWITTER') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		my $twitref = &ZTOOLKIT::parseparams($webdb->{'twitter'});
		$GTOOLSUI::TAG{'<!-- ACCESS_TOKEN -->'} = &ZOOVY::incode($twitref->{'access_token'});
		$GTOOLSUI::TAG{'<!-- ACCESS_SECRET -->'} = &ZOOVY::incode($twitref->{'access_secret'});
		$GTOOLSUI::TAG{'<!-- CONSUMER_KEY -->'} = &ZOOVY::incode($twitref->{'consumer_key'});
		$GTOOLSUI::TAG{'<!-- CONSUMER_SECRET -->'} = &ZOOVY::incode($twitref->{'consumer_secret'});
	
		$GTOOLSUI::TAG{'<!-- TWITTER_USERID -->'} = &ZOOVY::incode($ZOOVY::cgiv->{'twitter:userid'});
	
		$template_file = 'twitter.shtml';
		}
	
	
	
	
	
	#if ($VERB eq 'BLINKLOGIC-SAVE') {
	#	my %pref = ();
	#	$pref{'enable'} = int($ZOOVY::cgiv->{'enable'});
	#	$pref{'ftp_user'} = $ZOOVY::cgiv->{'ftp_user'};
	#	$pref{'ftp_pass'} = $ZOOVY::cgiv->{'ftp_pass'};
	#	$pref{'ftp_server'} = $ZOOVY::cgiv->{'ftp_server'};
	#	$WEBDB->{'blinklogic'} = &ZTOOLKIT::buildparams(\%pref);
	#	&ZWEBSITE::save_website_dbref($USERNAME,$WEBDB,$PRT);
	#	$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "Settings saved.";
	#	$VERB = 'BLINKLOGIC';
	#	}
	
	
	#if ($VERB eq 'BLINKLOGIC') {
	#	my ($pref) = &ZTOOLKIT::parseparams($WEBDB->{'blinklogic'});
	#	$GTOOLSUI::TAG{'<!-- ENABLE_0 -->'} = ($pref->{'enable'}==0)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- ENABLE_1 -->'} = ($pref->{'enable'}==1)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- FTP_USER -->'} = &ZOOVY::incode($pref->{'ftp_user'});
	#	$GTOOLSUI::TAG{'<!-- FTP_PASS -->'} = &ZOOVY::incode($pref->{'ftp_pass'});
	#	$GTOOLSUI::TAG{'<!-- FTP_SERVER -->'} = &ZOOVY::incode($pref->{'ftp_server'});
	#	$template_file = 'blinklogic.shtml';
	#	}
	
	if ($VERB eq 'DEBUG-RUN') {
	
		my ($lm) = LISTING::MSGS->new($USERNAME);
	
		#$SITE::merchant_id = $USERNAME;
		#$SITE::SREF->{'%NSREF'} = $NSREF;
		#$SITE::SREF->{'_NS'} = $PROFILE;
	
		$SITE::CART2 = CART2->new_memory($USERNAME,$PRT);
		$SITE::CART2->in_set('cart/refer',$ZOOVY::cgiv->{'meta'});
		my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT,'DOMAIN'=>$LU->domainname(),'*CART2'=>$SITE::CART2);
	
		my @MSGS = ();
		foreach my $i (1..3) {
			my $sku = $ZOOVY::cgiv->{"sku$i"};
			next if ($sku eq '');
	
			my $STID = $ZOOVY::cgiv->{"sku$i"};;
			next if ($STID eq '');
			my $QTY = 1;
	
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($STID);
			my ($P) = PRODUCT->new($USERNAME,$pid);
			my ($suggested_variations) = $P->suggest_variations('guess'=>1,'stid'=>$STID);
			foreach my $suggestion (@{$suggested_variations}) {
				if ($suggestion->[4] eq 'guess') {
					$lm->pooshmsg("WARN|+STID:$STID POG:$suggestion->[0] VALUE:$suggestion->[1] was guesssed (reason: not specified or invalid)");
					}
				}
			my $variations = STUFF2::variation_suggestions_to_selections($suggested_variations);
			$SITE::CART2->stuff2()->cram( $STID, $QTY, $variations, '*P'=>$P, '*LM'=>$lm );
			}
	
		foreach my $msg (@{$lm->msgs()}) {
			my ($ref,$status) = LISTING::MSGS->msg_to_disposition($msg);
			push @MSGS, "$ref->{'_'}|$ref->{'+'}";
			}
	
		#require SITE::MSGS;
		#$SITE::msgs = SITE::MSGS->new($USERNAME,PRT=>$PRT,CART2=>$SITE::CART2);
	
		use Data::Dumper;
	
		$SITE::CART2->in_set('our/orderid','2010-01-123456');
		my $out = $SITE->conversion_trackers($SITE::CART2);
	#	my $out = '';
	
		$GTOOLSUI::TAG{'<!-- DEBUG_OUT -->'} = '<hr><h1>OUTPUT:</h1><pre>'.&ZOOVY::incode($out).'</pre>';
	
		$GTOOLSUI::TAG{'<!-- DEBUG_OUT -->'} .= '<hr><h1>Additional Diagnostic Info:</h1><pre>'.&ZOOVY::incode(Dumper([\@MSGS,$SITE::CART2,$SITE])).'</pre>EOF';
		$VERB = 'DEBUG';
		}
	
	
	if ($VERB eq 'DEBUG') {
		$GTOOLSUI::TAG{'<!-- SKU1 -->'} = $ZOOVY::cgiv->{'sku1'};
		$GTOOLSUI::TAG{'<!-- SKU2 -->'} = $ZOOVY::cgiv->{'sku2'};
		$GTOOLSUI::TAG{'<!-- SKU3 -->'} = $ZOOVY::cgiv->{'sku3'};
		$GTOOLSUI::TAG{'<!-- META -->'} = $ZOOVY::cgiv->{'meta'};
	
		#my $profref = &DOMAIN::TOOLS::syndication_profiles($USERNAME,PRT=>$PRT);
		#my $c = '';
	   #foreach my $ns (sort keys %{$profref}) {
		#	my ($selected) = ($ZOOVY::cgiv->{'PROFILE'} eq $ns)?'selected':'';
		#	$c .= "<option $selected value=\"$ns\">$profref->{$ns}</option>";
		#	}
		#$GTOOLSUI::TAG{'<!-- PROFILES -->'} = $c;
		$template_file = 'debug.shtml';
		}
	
	
	
	if ($VERB eq 'GOOGAPI-RETURN') {
		if ($ZOOVY::cgiv->{'RESULT'} eq 'SUCCESS') {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "<font color='blue'>Successfully setup token</font><br>";
			}
		else {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "<font color='red'>Unspecified Error</font><br>";
			}
	
		$VERB = 'GOOGAPI';
		}
		
	if ($VERB eq 'GOOGAPI') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		$GTOOLSUI::TAG{'<!-- ANALYTICS_TOKEN -->'} = $webdb->{'google_token_analytics'};
		$template_file = 'googapi.shtml';
		}
	
	
	#if ($VERB eq 'RM-SAVE') {
	#	$NSREF->{'razormo:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
	#	&ZOOVY::savemerchantns_ref($USERNAME,$PROFILE,$NSREF);
	#	$VERB = 'RM';
	#	}
	#
	#if ($VERB eq 'RM') {
	#	push @BC, { name=>'RazorMouth' };	
	#	$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'razormo:chkoutjs'});
	#	if ($NSREF->{'razormo:chkoutjs'} =~ /http:/) {
	#		push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
	#		}
	#	$template_file = 'rm.shtml';
	#	push @BC, { name=>'RazorMouth' };	
	#	}
	
	
	##
	##
	##
	
	if ($VERB eq 'SAS-SAVE') {
		$NSREF->{'sas:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$VERB = 'SAS';
		}
	
	if ($VERB eq 'SAS') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'sas:chkoutjs'});
		if ($NSREF->{'sas:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'sas.shtml';
		push @BC, { name=>'Share-A-Sale' };	
		}
	
	
	##
	##
	##
	
	if ($VERB eq 'LINKSHARE-SAVE') {
		$NSREF->{'linkshare:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$VERB = 'LINKSHARE';
		}
	
	if ($VERB eq 'LINKSHARE') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'linkshare:chkoutjs'});
		if ($NSREF->{'linkshare:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'linkshare.shtml';
		push @BC, { name=>'LinkShare' };	
		}
	
	##
	##
	##
	
	if ($VERB eq 'BECOME-SAVE') {
		$NSREF->{'become:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'become:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved PRONTO plugin code","SAVE");
		$VERB = 'BECOME';
		}
	
	
	if ($VERB eq 'BECOME') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'become:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'become:filter'})?'checked':'';
	
		if ($NSREF->{'become:chkoutjs'} =~ /PUT_YOUR_DATA_HERE/) {
			push @WARNINGS, "PUT_YOUR_DATA_HERE is not a valid variable.";
			}
		if ($NSREF->{'become:chkoutjs'} =~ /\%OrderID\%/) {
			push @WARNINGS, "%OrderID% is not a valid Zoovy variable, you probably meant to customize this.";
			}
		if ($NSREF->{'become:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'become.shtml';
		push @BC, { name=>'Become.com' };
		}
	
	
	##
	if ($VERB eq 'OTHER-SAVE') {
		$NSREF->{'plugin:headjs'} = $ZOOVY::cgiv->{'head_code'};
		$NSREF->{'zoovy:head_nonsecure'} = $ZOOVY::cgiv->{'head_nonsecure_code'};
		$NSREF->{'zoovy:head_secure'} = $ZOOVY::cgiv->{'head_secure_code'};
	
		$NSREF->{'plugin:footerjs'} = $ZOOVY::cgiv->{'footer_code'};
		$NSREF->{'plugin:loginjs'} = $ZOOVY::cgiv->{'login_code'};
		$NSREF->{'plugin:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'plugin:invoicejs'} = $ZOOVY::cgiv->{'invoice_code'};
	
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved OTHER plugin code","SAVE");
		$VERB = 'OTHER';
		}
	
	
	if ($VERB eq 'OTHER') {
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'plugin:headjs'});
		$GTOOLSUI::TAG{'<!-- HEAD_NONSECURE_CODE -->'} = &ZOOVY::incode($NSREF->{'zoovy:head_nonsecure'});
		$GTOOLSUI::TAG{'<!-- HEAD_SECURE_CODE -->'} = &ZOOVY::incode($NSREF->{'zoovy:head_secure'});
		$GTOOLSUI::TAG{'<!-- LOGIN_CODE -->'} = &ZOOVY::incode($NSREF->{'plugin:loginjs'});
		$GTOOLSUI::TAG{'<!-- FOOTER_CODE -->'} = &ZOOVY::incode($NSREF->{'plugin:footerjs'});
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'plugin:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- INVOICE_CODE -->'} = &ZOOVY::incode($NSREF->{'plugin:invoicejs'});
		$template_file = 'other.shtml';
	
		if ($NSREF->{'zoovy:head_secure'} =~ /favico/) {
			push @WARNINGS, "You should not reference a favico in head_secure - this will cause errors on your site. Please reference webdoc.";
			}
		if ($NSREF->{'zoovy:head_nonsecure'} =~ /favico/) {
			push @WARNINGS, "You should not reference a favico in head_nonsecure - this will cause errors on your site. Please reference webdoc.";
			}
		if ($NSREF->{'plugin:headjs'} =~ /favico/) {
			push @WARNINGS, "You should not reference a favico in headjs - this will cause errors on your site. Please reference webdoc.";
			}
	
		if ($NSREF->{'plugin:footerjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_FOOTER_REFERENCE;
			}
		if ($NSREF->{'plugin:chkoutjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		if ($NSREF->{'plugin:loginjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
	
		push @BC, { name=>'Other' };
		}
	
	
	
	
	if ($VERB eq 'KOUNT-SAVE') {
		require PLUGIN::KOUNT;
	
	#	my $apifile = PLUGIN::KOUNT::pem_file($USERNAME,$PRT,"api");
	#	open F, ">$apifile";
	#	print F $ZOOVY::cgiv->{'api'};
	#	close F;
	#	chown 65534,65534, $apifile;
	
	#	my $risfile = PLUGIN::KOUNT::pem_file($USERNAME,$PRT,"ris");
	#	open F, ">$risfile";
	#	print F $ZOOVY::cgiv->{'ris'};
	#	close F;
	#	chown 65534,65534, $risfile;
		
		if (($ZOOVY::cgiv->{'RIS-CERT'} ne '') && ($ZOOVY::cgiv->{'RIS-PASS'} ne '')) {
			## if we have a CERT-RIS then save it.
			my $fh = $ZOOVY::cgiv->{'RIS-CERT'};
			$/ = undef; my $out = <$fh>; $/ = "\n";
	
			my $pass = $ZOOVY::cgiv->{'RIS-PASS'};
	
			my $tmpfile = "/tmp/kount-$$.p12";	
			open F, ">$tmpfile"; print F $out; close F;
			my $tmpfile2 = "/tmp/kount-$$.pm";	
			my ($cmd) = "/usr/bin/openssl pkcs12 -in $tmpfile -out $tmpfile2 -nodes -passin pass:$pass\n";
			print STDERR $cmd;
			system($cmd);
	
			open F, "<$tmpfile2"; $/ = undef; my ($pem) = <F>; $/ = "\n"; close F; 
	
			my ($pk) = PLUGIN::KOUNT->new($USERNAME,prt=>$PRT);
			open F, ">".$pk->pem_file("RIS");
			print F $pem;
			close F;
			}
	
		my ($cfg) = PLUGIN::KOUNT::load_config($USERNAME,$PRT);
		$cfg->{'enable'} = int($ZOOVY::cgiv->{'kount_enable'});
		$cfg->{'multisite'} = $ZOOVY::cgiv->{'kount_multisite'};
		$cfg->{'prodtype'} = $ZOOVY::cgiv->{'kount_prodtype'};
		
		PLUGIN::KOUNT::save_config($USERNAME,$PRT,$cfg);
	
	#	$WEBDB->{'kount'} = int($ZOOVY::cgiv->{'kount_enable'});
	#	my ($pref) = &ZTOOLKIT::parseparams($WEBDB->{'kount_config'});
	#	$WEBDB->{'kount_config'} = &ZTOOLKIT::buildparams($pref);
	#	&ZWEBSITE::save_website_dbref($USERNAME,$WEBDB,$PRT);
		$VERB = 'KOUNT';
		}
	
	if ($VERB eq 'KOUNT') {
		require PLUGIN::KOUNT;
		my ($ID) = &PLUGIN::KOUNT::resolve_kountid($USERNAME,$PRT);
		if ($ID==0) { $VERB = 'KOUNT-REGISTER'; }
		}
	
	if ($VERB eq 'KOUNT-PROVISION') {
		require PLUGIN::KOUNT;
		$VERB = 'KOUNT'; 
		}
	
	if ($VERB eq 'KOUNT-REGISTER') {
		$template_file = 'kount-register.shtml';
		}
	
	
	if ($VERB eq 'KOUNT') {
	
	#	my $apifile = PLUGIN::KOUNT::pem_file($USERNAME,$PRT,"api");
	#	open F, "<$apifile"; $/ = undef; $GTOOLSUI::TAG{'<!-- API -->'} = &ZOOVY::incode(<F>); $/ = "\n"; close F;
	#
	#	my $risfile = PLUGIN::KOUNT::pem_file($USERNAME,$PRT,"ris");
	#	open F, "<$risfile"; $/ = undef; $GTOOLSUI::TAG{'<!-- RIS -->'} = &ZOOVY::incode(<F>); $/ = "\n"; close F;
	
		my ($kcfg) = &PLUGIN::KOUNT::load_config($USERNAME);
	
		# $WEBDB->{'kount'} = int($WEBDB->{'kount'});
		$GTOOLSUI::TAG{'<!-- ENABLE_0 -->'} = ($kcfg->{'enable'}==0)?'selected':'';
		$GTOOLSUI::TAG{'<!-- ENABLE_1 -->'} = ($kcfg->{'enable'}==1)?'selected':'';
		$GTOOLSUI::TAG{'<!-- ENABLE_2 -->'} = ($kcfg->{'enable'}==2)?'selected':'';
	
		$GTOOLSUI::TAG{'<!-- MULTISITE_ -->'} = ($kcfg->{'multisite'} eq '')?'selected':'';
		$GTOOLSUI::TAG{'<!-- MULTISITE_SDOMAIN -->'} = ($kcfg->{'multisite'} eq 'sdomain')?'selected':'';
		$GTOOLSUI::TAG{'<!-- MULTISITE_PRT -->'} = ($kcfg->{'multisite'} eq 'prt')?'selected':'';
	
		$GTOOLSUI::TAG{'<!-- PRODTYPE_ZOOVY:CATALOG -->'} = ($kcfg->{'prodtype'} eq 'zoovy:catalog')?'selected':'';
		$GTOOLSUI::TAG{'<!-- PRODTYPE_ZOOVY:PROD_BRAND -->'} = ($kcfg->{'prodtype'} eq 'zoovy:prod_brand')?'selected':'';
		$GTOOLSUI::TAG{'<!-- PRODTYPE_ZOOVY:PROD_SHIPCLASS -->'} = ($kcfg->{'prodtype'} eq 'zoovy:prod_shipclass')?'selected':'';
		$GTOOLSUI::TAG{'<!-- PRODTYPE_ZOOVY:PROD_PROMOCLASS -->'} = ($kcfg->{'prodtype'} eq 'zoovy:prod_promoclass')?'selected':'';
	
		$GTOOLSUI::TAG{'<!-- MERCHANT -->'} = &ZOOVY::incode($kcfg->{'merchant'});
	
		require PLUGIN::KOUNT;
		my ($pk) = PLUGIN::KOUNT->new($USERNAME,prt=>$PRT);
	#	$GTOOLSUI::TAG{'<!-- RIS_FILE -->'} = (-f $pk->pem_file('RIS'))?'installed':qq~<b>Not Installed/Required:</b>
	#<br>PKCS12 RIS File: <input type="file" name="RIS-CERT"><br>
	#PCKS12 Pass: <input type="textbox" name="RIS-PASS"><br>~;
	#	$GTOOLSUI::TAG{'<!-- API_FILE -->'} = (-f $pk->pem_file('API'))?'installed':'not installed';
		$GTOOLSUI::TAG{'<!-- PASSWORD -->'} = ($LU->is_admin())?$pk->password():'** REQUIRES ADMIN **';
	
		$template_file = 'kount.shtml';
		}
	
	
	
	##
	## Google Analytics.
	##
	if ($VERB eq 'GOOGLEAN-SAVE') {
		$NSREF->{'analytics:headjs'} = $ZOOVY::cgiv->{'head_code'};
		$NSREF->{'analytics:syndication'} = (defined $ZOOVY::cgiv->{'syndication'})?'GOOGLE':'';
		$NSREF->{'analytics:roi'} = 'GOOGLE';
		$NSREF->{'analytics:linker'} = (defined $ZOOVY::cgiv->{'linker'})?time():'';
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved GOOGLE plugin code","SAVE");
		$VERB = 'GOOGLEAN';
		}
	
	
	if ($VERB eq 'GOOGLEAN') {
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'analytics:headjs'});
		$GTOOLSUI::TAG{'<!-- CHK_ROI -->'} = ($NSREF->{'analytics:roi'} eq 'GOOGLE')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHK_SYNDICATION -->'} = ($NSREF->{'analytics:syndication'} eq 'GOOGLE')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHK_LINKER -->'} = ($NSREF->{'analytics:linker'}>0)?'checked':'';
	
		if ($GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} =~ /XXXXX/) {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = qq~ <div class="error">Zoovy Marketing Services Google Analytics Code has not been customized and will not work.</div>~;
			}
	
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		if ($webdb->{'google_api_env'}==0) {
			## no google checkout
			}
		elsif ($webdb->{'google_api_analytics'}==0) {
			##
			## analytics/api - 
			##
			$GTOOLSUI::TAG{'<!-- GOOGLE_CHECKOUT_STATUS -->'} = qq~
	<div class="alert">
	Google Checkout is currently enabled, but analytics tracking is not. Please go to Setup | Payments | Google Checkout |
	and enable "Google Analytics Support" to ensure accurate reporting.
	</div>
	~;
			}
		elsif ($webdb->{'google_api_analytics'}==1) {
			## 
			$GTOOLSUI::TAG{'<!-- GOOGLE_CHECKOUT_STATUS -->'} = qq~<div class="success">Google Checkout is currently enabled and configured to use non-Async (pagetracker) Code.</div>~;
			if ($NSREF->{'analytics:headjs'} !~ /pagetracker/i) {
				$GTOOLSUI::TAG{'<!-- GOOGLE_CHECKOUT_STATUS -->'} = qq~<div class="error">Google Checkout analytics support is currently enabled, but it does not appear to match our analytics code release.</div>~;
				}
			}
		elsif ($webdb->{'google_api_analytics'}==2) {
			## 
			$GTOOLSUI::TAG{'<!-- GOOGLE_CHECKOUT_STATUS -->'} = qq~<div class="success">Google Checkout is currently enabled and configured to use Async (gaq) Code.</div>~;
			if ($NSREF->{'analytics:headjs'} !~ /_gaq/i) {
				$GTOOLSUI::TAG{'<!-- GOOGLE_CHECKOUT_STATUS -->'} = qq~<div class="error">Google Checkout analytics support is currently enabled, but it does not appear to match our analytics code release.</div>~;
				}
			}
	
	
		if ($NSREF->{'analytics:headjs'} =~ /urchin/) {
			push @WARNINGS, "Appears to have older 'urchin' version of the google code. Many zoovy features (such as Google Checkout) will not work.";
			}
	
	
	#	require DOMAIN::TOOLS;
	#	my ($DOMAIN) = &DOMAIN::TOOLS::domain_for_profile($USERNAME,$PROFILE);
	#	my $zmsjs = '';
	#	open F, "<ga.txt";
	#	$/ = undef; $zmsjs = <F>; $/ = "\n";
	#	close F;
	#	$zmsjs =~ s/%DOMAIN%/$DOMAIN/gs;
	#
	#	require URI::Escape;
	#	$GTOOLSUI::TAG{'<!-- ZMSJS -->'} = ZOOVY::incode($zmsjs);
	#	
		$template_file = 'googlean.shtml';
		push @BC, { name=>'Google Analytics' };
		}
	
	
	
	
	
	
	
	###############################################################################
	##
	## Google Webmaster Tools
	##
	if ($VERB eq 'SAVE-GOOGLEWMT') {
		# Saves changes to the sitemap
		my $ERRORS = 0;
	
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,'PRT'=>$PRT);
	
		foreach my $domain (sort @domains) {
			if (defined($ZOOVY::cgiv->{$domain})) {
				my ($D) = DOMAIN->new($USERNAME,$domain);
				next if (not defined $D);
				$D->set('GOOGLE_SITEMAP',$ZOOVY::cgiv->{$domain});
				$D->save();
				}
			}
	
		$LU->log('SETUP.GOOGLEWMT',"Updated sitemap settings",'SAVE');
	
		if ($ERRORS == 0) {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Successfully Saved!</b></font></center><br><br>";
			}
		else {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Unable to SiteMaps!</b></font></center><br><br>"; 
			}	
		$VERB = 'GOOGLEWMT';
		}
	
	
	if ($VERB eq 'GOOGLEWMT') {
		$template_file = 'googlewmt.shtml';
		$help = "#50596";
	
		push @BC, { name=>'Google Webmaster' };	
	
		$GTOOLSUI::TAG{'<!-- TS -->'} = time();
		my $out = '';
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
		my $i = 0;
		foreach my $domain (sort @domains) {
			## get value for webdb.bin
			my $value = '';
			my ($D) = DOMAIN->new($USERNAME,$domain);
		
			$out .= "<tr>";
			$out .= "<td>$domain</td>";
			if ($D->{'WWW_HOST_TYPE'} eq 'VSTORE') {			
				$value = $D->{'GOOGLE_SITEMAP'};
				$value = &ZOOVY::incode($value);
				$out .= qq~<td>www.$domain <input type="text" name="$domain" value="$value" size=80></td>~;
				$i++;
				}
			$out .= "</tr>\n"; 
			}
	
		if ($out eq '') {
			$out .= "<tr><td><i>You currently have no VSTORE sites associated</i></td></tr>";
			}
	
		if ($i>1) {
			$GTOOLSUI::TAG{'<!-- WARNINGS -->'} = qq~
	<tr>
		<td class="rs" colspan=2>
		<b>DUPLICATE CONTENT WARNING</b><br>
		<font class="hint">
		You currently have more than one domain pointing to the same profile/homepage.
		SEO best practices state that you configure all other domains as redirects to your primary domain.
		Example: yourdomain.net, yourdomain.org, yourdomain.us all should redirect to yourdomain.com. 
		You could be inadvertantly hurting your search engine ranking. Go into Setup / Domain Configuration
		to correct this.
		</font>
		</td>
	</tr>
	~;
			}
	
	
		$GTOOLSUI::TAG{'<!-- DOMAINS -->'} = $out;
		## not used
				
		}
	
	
	
	
	##
	## YAHOO WEBMASTER TOOLS
	##
	if ($VERB eq 'SAVE-YAHOOWMT') {
		# Saves changes to the sitemap
		my $ERRORS = 0;
	
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
	
		foreach my $domain (sort @domains) {
			if (defined($ZOOVY::cgiv->{$domain})) {
				my ($D) = DOMAIN->new($USERNAME,$domain);
				next if (not defined $D);
				$D->set('YAHOO_SITEMAP',$ZOOVY::cgiv->{$domain});
				$D->save();
				}
			}
	
		$LU->log('SETUP.YAHOOWMT',"Updated yahoo sitemap settings",'SAVE');
	
		if ($ERRORS == 0) {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Successfully Saved!</b></font></center><br><br>";
			}
		else {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Unable to SiteMaps!</b></font></center><br><br>"; 
			}	
		$VERB = 'YAHOOWMT';
		}
	
	
	if ($VERB eq 'YAHOOWMT') {
		$template_file = 'yahoowmt.shtml';
		$help = "#50596";
	
		push @BC, { name=>'Yahoo Webmaster' };	
	
		$GTOOLSUI::TAG{'<!-- TS -->'} = time();
		my $out = '';
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
		my $i = 0;
		foreach my $domain (sort @domains) {
			## get value for webdb.bin
			my $value = '';
			my ($D) = DOMAIN->new($USERNAME,$domain);
		
			$out .= "<tr>";
			$out .= "<td>$domain</td>";
			if ($D->{'WWW_HOST_TYPE'} eq 'VSTORE') {
				$value = $D->{'YAHOO_SITEMAP'};
				$value = &ZOOVY::incode($value);
				$out .= qq~<td><input type="text" name="$domain" value="$value" size=80></td>~;
				$i++;
				}
			$out .= "</tr>\n"; 
			}
	
		if ($out eq '') {
			$out .= "<tr><td><i>You currently have no VSTORE sites associated</i></td></tr>";
			}
	
		if ($i>1) {
			$GTOOLSUI::TAG{'<!-- WARNINGS -->'} = qq~
	<tr>
		<td class="rs" colspan=2>
		<b>DUPLICATE CONTENT WARNING</b><br>
		<font class="hint">
		You currently have more than one domain pointing to the same profile/homepage.
		SEO best practices state that you configure all other domains as redirects to your primary domain.
		Example: yourdomain.net, yourdomain.org, yourdomain.us all should redirect to yourdomain.com. 
		You could be inadvertantly hurting your search engine ranking. Go into Setup / Domain Configuration
		to correct this.
		</font>
		</td>
	</tr>
	~;
			}
	
	
		$GTOOLSUI::TAG{'<!-- DOMAINS -->'} = $out;
		## not used
				
		}
	
	
	
	
	##
	## BING WEBMASTER TOOLS
	##
	if ($VERB eq 'SAVE-BINGWMT') {
		# Saves changes to the sitemap
		my $ERRORS = 0;
	
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
	
		foreach my $domain (sort @domains) {
			if (defined($ZOOVY::cgiv->{$domain})) {
				my ($D) = DOMAIN->new($USERNAME,$domain);
				next if (not defined $D);
				$D->set('BING_SITEMAP',$ZOOVY::cgiv->{$domain});
				$D->save();
				}
			}
	
		$LU->log('SETUP.BINGWMT',"Updated bing sitemap settings",'SAVE');
	
		if ($ERRORS == 0) {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Successfully Saved!</b></font></center><br><br>";
			}
		else {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} .= "<center><font face='helvetica, arial' color='red' size='5'><b>Unable to SiteMaps!</b></font></center><br><br>"; 
			}	
		$VERB = 'BINGWMT';
		}
	
	
	if ($VERB eq 'BINGWMT') {
		$template_file = 'bingwmt.shtml';
		$help = "#50596";
	
		$GTOOLSUI::TAG{'<!-- TS -->'} = time();
		my $out = '';
		require DOMAIN::TOOLS;
		require DOMAIN;
		my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
		my $i = 0;
		foreach my $domain (sort @domains) {
			## get value for webdb.bin
			my $value = '';
			my ($D) = DOMAIN->new($USERNAME,$domain);
		
			$out .= "<tr>";
			$out .= "<td>$domain</td>";
			if ($D->{'WWW_HOST_TYPE'} eq 'VSTORE') {
				$value = $D->{'BING_SITEMAP'};
				$value = &ZOOVY::incode($value);
				$out .= qq~<td><input type="text" name="$domain" value="$value" size=80></td>~;
				$i++;
				}
			$out .= "</tr>\n"; 
			}
	
		if ($out eq '') {
			$out .= "<tr><td><i>You currently have no VSTORE sites associated</i></td></tr>";
			}
	
		if ($i>1) {
			$GTOOLSUI::TAG{'<!-- WARNINGS -->'} = qq~
	<tr>
		<td class="rs" colspan=2>
		<b>DUPLICATE CONTENT WARNING</b><br>
		<font class="hint">
		You currently have more than one domain pointing to the same profile/homepage.
		SEO best practices state that you configure all other domains as redirects to your primary domain.
		Example: yourdomain.net, yourdomain.org, yourdomain.us all should redirect to yourdomain.com. 
		You could be inadvertantly hurting your search engine ranking. Go into Setup / Domain Configuration
		to correct this.
		</font>
		</td>
	</tr>
	~;
			}
	
	
		$GTOOLSUI::TAG{'<!-- DOMAINS -->'} = $out;
		## not used
				
		}
	
	
	
	
	##
	##
	##
	if ($VERB eq 'OMNITURE-SAVE') {	
		$NSREF->{'silverpop:listid'} = $ZOOVY::cgiv->{'silverpop:listid'};
		$NSREF->{'silverpop:enable'} = ($ZOOVY::cgiv->{'silverpop:enable'})?1:0;
	
		$NSREF->{'omniture:enable'} = (defined $ZOOVY::cgiv->{'enable'})?time():0;
		$NSREF->{'omniture:headjs'} = $ZOOVY::cgiv->{'head_code'};
		$NSREF->{'omniture:footerjs'} = $ZOOVY::cgiv->{'footer_code'};
		$NSREF->{'omniture:checkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'omniture:cartjs'} = $ZOOVY::cgiv->{'cart_code'};
		$NSREF->{'omniture:categoryjs'} = $ZOOVY::cgiv->{'category_code'};
		$NSREF->{'omniture:productjs'} = $ZOOVY::cgiv->{'product_code'};
		$NSREF->{'omniture:resultjs'} = $ZOOVY::cgiv->{'result_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved OMNITURE plugin code","SAVE");
		$VERB = 'OMNITURE';
		}
	
	if ($VERB eq 'OMNITURE') {
		$GTOOLSUI::TAG{'<!-- CHK_SILVERPOP -->'} = ($NSREF->{'silverpop:enable'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- SILVERPOP_LISTID -->'} = &ZOOVY::incode($NSREF->{'silverpop:listid'});
	
		$GTOOLSUI::TAG{'<!-- CHK_ENABLE -->'} = ($NSREF->{'omniture:enable'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- DISABLE_WARNING -->'} = ($NSREF->{'omniture:enable'})?'':'<font color="red">Warning: currently disabled, none of the settings below will be used.</font><br>';
	
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:headjs'});
		$GTOOLSUI::TAG{'<!-- FOOTER_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:footerjs'});
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:checkoutjs'});
		$GTOOLSUI::TAG{'<!-- CART_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:cartjs'});
		$GTOOLSUI::TAG{'<!-- CATEGORY_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:categoryjs'});
		$GTOOLSUI::TAG{'<!-- PRODUCT_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:productjs'});
		$GTOOLSUI::TAG{'<!-- RESULT_CODE -->'} = &ZOOVY::incode($NSREF->{'omniture:resultjs'});
		$template_file = 'omniture.shtml';
		push @BC, { name=>'Omniture' };
		}
	
	
	##
	##
	##
	if ($VERB eq 'SHOPCOM-SAVE') {
	#	$NSREF->{'shopcom:headjs'} = $ZOOVY::cgiv->{'head_code'};
		$NSREF->{'shopcom:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$NSREF->{'shopcom:chkoutjs'} = $ZOOVY::cgiv->{'chkout_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved SHOPCOM plugin code","SAVE");
		$VERB = 'SHOPCOM';
		}
	
	if ($VERB eq 'SHOPCOM') {
	#	$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'shopcom:headjs'});
		$GTOOLSUI::TAG{'<!-- CHKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'shopcom:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'shopcom:filter'})?'checked':'';
		if ($NSREF->{'shopcom:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'shopcom.shtml';
		push @BC, { name=>'Shopping.com/Dealtime' };
		}
	
	
	##
	##
	##
	if ($VERB eq 'YAHOO-SAVE') {
		$NSREF->{'yahooshop:headjs'} = $ZOOVY::cgiv->{'head_code'};
		$NSREF->{'yahooshop:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$NSREF->{'yahooshop:chkoutjs'} = $ZOOVY::cgiv->{'chkout_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved YAHOO plugin code","SAVE");
		$VERB = 'YAHOO';
		}
	
	if ($VERB eq 'YAHOO') {
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'yahooshop:headjs'});
		$GTOOLSUI::TAG{'<!-- CHKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'yahooshop:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'yahooshop:filter'})?'checked':'';
		if ($NSREF->{'yahooshop:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
	
		if ($NSREF->{'yahooshop:chkoutjs'} =~ /transId=\,currency=\,amount=/) {
			push @WARNINGS, "transId variable not interpolated";
			}
	
		$template_file = 'yahooshop.shtml';
		push @BC, { name=>'Yahoo' };
		}
	
	##
	##
	##
	
	
	if ($VERB eq 'FACEBOOK-SAVE') {
		$NSREF->{'facebook:url'} = $ZOOVY::cgiv->{'facebook:url'};
		$NSREF->{'facebook:chkout'} = (defined $ZOOVY::cgiv->{'facebook:chkout'})?1:0;
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved FACEBOOK settings","SAVE");
		$VERB = 'FACEBOOK';
		}
	
	if ($VERB eq 'FACEBOOK') {
		$GTOOLSUI::TAG{'<!-- FACEBOOK_URL -->'} = &ZOOVY::incode($NSREF->{'facebook:url'});
		$GTOOLSUI::TAG{'<!-- CHK_FACEBOOK_CHKOUT -->'} = ($NSREF->{'facebook:chkout'})?'checked':'';
	
		$GTOOLSUI::TAG{'<!-- SIDEBAR_WARNING -->'} = '';
		if (($NSREF->{'facebook:url'} ne '') && ($NSREF->{'zoovy:sidebar_html'} !~ /facebook/)) {
			$GTOOLSUI::TAG{'<!-- SIDEBAR_WARNING -->'} = "<font color='red'>Facebook does not appear in sidebar</font>";
			}
	
		$template_file = 'facebook.shtml';
		}
	
	
	#if ($VERB eq 'TWITTER-SAVE') {
	#	$NSREF->{'twitter:url'} = $ZOOVY::cgiv->{'twitter:url'};
	#	$NSREF->{'twitter:chkout'} = (defined $ZOOVY::cgiv->{'twitter:chkout'})?'checked':'';
	#
	#	$template_file = 'twitter.shtml';
	#	push @BC, { name=>'Twitter' };
	#	}
	
	##
	##
	##
	
	if ($VERB eq 'WISHPOT-SAVE') {
		$NSREF->{'wishpot:merchantid'} = $ZOOVY::cgiv->{'wishpot:merchantid'};
		$NSREF->{'wishpot:wishlist'} = (defined $ZOOVY::cgiv->{'wishpot:wishlist'})?1:0;
		$NSREF->{'wishpot:facebook'} = (defined $ZOOVY::cgiv->{'wishpot:facebook'})?1:0;
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved WISHPOT settings","SAVE");
	
		my ($so) = SYNDICATION->new($USERNAME,'WSH','DOMAIN'=>$D->domainname());
		if (($NSREF->{'wishpot:merchantid'} eq '') || ($NSREF->{'wishpot:facebook'}==0)) {
		   $so->nuke();
			}
		else {
			$so->set('IS_ACTIVE',1);
			$so->save();
			}
		
	
		$VERB = 'WISHPOT';
		}
	
	if ($VERB eq 'WISHPOT') {
		my ($so) = SYNDICATION->new($USERNAME,'WSH',DOMAIN=>$D->domainname());
		$GTOOLSUI::TAG{'<!-- FEED_STATUS -->'} = $so->statustxt();
	
		$GTOOLSUI::TAG{'<!-- WISHPOT_MERCHANTID -->'} = &ZOOVY::incode($NSREF->{'wishpot:merchantid'});
		$GTOOLSUI::TAG{'<!-- CHK_WISHLIST -->'} = ($NSREF->{'wishpot:wishlist'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHK_FACEBOOK -->'} = ($NSREF->{'wishpot:facebook'})?'checked':'';
	
		$template_file = 'wishpot.shtml';
		}
	
	
	if ($VERB eq 'VERUTA') {
		push @BC, { name=>'Veruta' };	
		$template_file = 'veruta.shtml';
		}
	
	
	##
	##
	##
	if ($VERB eq 'FETCHBACK-SAVE') {
		$NSREF->{'fetchback:loginjs'} = $ZOOVY::cgiv->{'fetchback:loginjs'};
		$NSREF->{'fetchback:chkoutjs'} = $ZOOVY::cgiv->{'fetchback:chkoutjs'};
		$NSREF->{'fetchback:cartjs'} = $ZOOVY::cgiv->{'fetchback:cartjs'};
		$NSREF->{'fetchback:footerjs'} = $ZOOVY::cgiv->{'fetchback:footerjs'};	
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved FETCHBACK plugin code","SAVE");
		$VERB = 'FETCHBACK';	
		}
	
	if ($VERB eq 'FETCHBACK') {
		push @BC, { name=>'Fetchback' };	
		$GTOOLSUI::TAG{'<!-- LOGINJS -->'} = &ZOOVY::incode($NSREF->{'fetchback:loginjs'});
		$GTOOLSUI::TAG{'<!-- CHKOUTJS -->'} = &ZOOVY::incode($NSREF->{'fetchback:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CARTJS -->'} = &ZOOVY::incode($NSREF->{'fetchback:cartjs'});
		$GTOOLSUI::TAG{'<!-- FOOTERJS -->'} = &ZOOVY::incode($NSREF->{'fetchback:footerjs'});
	
		if ($NSREF->{'fetchback:loginjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_LOGIN_REFERENCE;
			}
		if ($NSREF->{'fetchback:footerjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_FOOTER_REFERENCE;
			}
		if ($NSREF->{'fetchback:chkoutjs'} =~ /http\:\/\//) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
	
		$template_file = 'fetchback.shtml';
		}
	
	
	
	##
	##
	##
	#if ($VERB eq 'LIVECHAT-SAVE') {
	#	$NSREF->{'livechat:licenseid'} = $ZOOVY::cgiv->{'licenseid'};
	#	$NSREF->{'livechat:tracking'} = $ZOOVY::cgiv->{'tracking'};
	#	$D->from_legacy_nsref($NSREF); $D->save();
	#	$LU->log("SETUP.PLUGIN","Saved LIVECHAT plugin code","SAVE");
	#	$VERB = 'LIVECHAT';
	#	}
	#
	#if ($VERB eq 'LIVECHAT') {
	#	## LIVECHAT security key:
	#	$GTOOLSUI::TAG{'<!-- SECURITY_KEY -->'} = sprintf("%X:%s",$MID,$PROFILE);
	#	$GTOOLSUI::TAG{'<!-- LICENSEID -->'} = &ZOOVY::incode($NSREF->{'livechat:licenseid'});
	#	$GTOOLSUI::TAG{'<!-- TRACKING -->'} = &ZOOVY::incode($NSREF->{'livechat:tracking'});
	#
	#	$template_file = 'livechat.shtml';
	#	push @BC, { name=>'LiveChat' };
	#	}
	
	
	##
	##
	##
	
	if ($VERB eq 'OLARK-SAVE') {
		$NSREF->{'olark:html'} = $ZOOVY::cgiv->{'html'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved OLARK plugin code","SAVE");
		$VERB = 'OLARK';
		}
	
	if ($VERB eq 'OLARK') {
		## LIVECHAT security key:
		$GTOOLSUI::TAG{'<!-- HTML -->'} = &ZOOVY::incode($NSREF->{'olark:html'});
	
		$template_file = 'olark.shtml';
		push @BC, { name=>'OLark' };
		}
	
	
	
	##
	##
	##
	
	if ($VERB eq 'PROVIDESUPPORT-SAVE') {
		$NSREF->{'pschat:html'} = $ZOOVY::cgiv->{'html'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved PROVIDESUPPORT plugin code","SAVE");
		$VERB = 'PROVIDESUPPORT';
		}
	
	if ($VERB eq 'PROVIDESUPPORT') {
		## LIVECHAT security key:
		$GTOOLSUI::TAG{'<!-- HTML -->'} = &ZOOVY::incode($NSREF->{'pschat:html'});
	
		$template_file = 'providesupport.shtml';
		push @BC, { name=>'ProvideSupport' };
		}
	
	
	
	# UPSELLIT
	#
	if ($VERB eq 'UPSELLIT-SAVE') {
		$NSREF->{'upsellit:footerjs'} = $ZOOVY::cgiv->{'footerjs'};
		$NSREF->{'upsellit:chkoutjs'} = $ZOOVY::cgiv->{'chkoutjs'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved UPSELLIT code","SAVE");
		$VERB = 'UPSELLIT';
		}
	
	if ($VERB eq 'UPSELLIT') {
		$GTOOLSUI::TAG{'<!-- FOOTERJS -->'} = &ZOOVY::incode($NSREF->{'upsellit:footerjs'});
		$GTOOLSUI::TAG{'<!-- CHKOUTJS -->'} = &ZOOVY::incode($NSREF->{'upsellit:chkoutjs'});
		if ($NSREF->{'upsellit:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'upsellit.shtml';
		push @BC, { name=>'UpSellIt' };
		}
	
	
	
	
	##
	##
	##
	if ($VERB eq 'POWERREVIEWS-SAVE') {
		$NSREF->{'powerreviews:merchantid'} = $ZOOVY::cgiv->{'merchantid'};
		$NSREF->{'powerreviews:enable'} = (defined $ZOOVY::cgiv->{'enable'})?1:0;
		$NSREF->{'powerreviews:groupid'} = $ZOOVY::cgiv->{'groupid'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved POWERREVIEWS code","SAVE");
	
	
	## Product page:
	## <script type="text/javascript">
	# var pr_style_sheet="http://cdn.powerreviews.com/aux/10942/2953/css/powerreviews_express.css";
	# </script>
	# <script type="text/javascript" src="http://cdn.powerreviews.com/repos/10942/pr/pwr/engine/js/full.js"></script>
	##
	##
	# 
	#Review this
	# <div class="pr_snippet_product">
	# <script type="text/javascript">POWERREVIEWS.display.snippet(document, { pr_page_id : "PAGE_ID" });</script>
	# </div>
	#
	#Review Javascript:
	# <div class="pr_review_summary">
	# <script type="text/javascript">POWERREVIEWS.display.engine(document, { pr_page_id : "PAGE_ID" });</script>
	# </div>
	#
	
	# Category Page (header)
	#<script type="text/javascript">
	#var pr_style_sheet="http://cdn.powerreviews.com/aux/10942/2953/css/powerreviews_express.css";
	#</script>
	#<script type="text/javascript" src="http://cdn.powerreviews.com/repos/10942/pr/pwr/engine/js/full.js"></script>
	
	# Category Page (review spot)
	#<div class="pr_snippet_category">
	#<script type="text/javascript">
	#var pr_snippet_min_reviews=0;
	#POWERREVIEWS.display.snippet(document, { pr_page_id : "PAGE_ID" });
	#</script>
	#</div>
	
		$VERB = 'POWERREVIEWS';
		}
	
	
	if (($VERB eq 'POWERREVIEWS') && ($FLAGS =~ /,PR,/)) {
		
		}
	
	if ($VERB eq 'POWERREVIEWS') {
		## POWERREVIEWS security key:
		require ZTOOLKIT::SECUREKEY;
		my ($KEY) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'PR');
		my $PROFILE = 'DEFAULT';
		$KEY = sprintf("%s:%s:%s:%s",uc($USERNAME),uc($PRT),$KEY,$PROFILE);
		my ($so) = SYNDICATION->new($USERNAME,'PRV','DOMAIN'=>$D->domainname());
		my ($LASTRUN_GMT) = $so->get('PRODUCTS_LASTRUN_GMT');
	
		if ($LASTRUN_GMT>0) {
			$GTOOLSUI::TAG{'<!-- FILE_STATUS -->'} = qq~<a href="http://webapi.zoovy.com/webapi/powerreviews?key=$KEY">
		http://webapi.zoovy.com/webapi/powerreviews?key=$KEY
		</a><br>Last Generated: ~.&ZTOOLKIT::pretty_date($LASTRUN_GMT);
			}
		else {
			$GTOOLSUI::TAG{'<!-- FILE_STATUS -->'} = qq~-- please generate file --~;
			}
	
		$GTOOLSUI::TAG{'<!-- KEY -->'} = $KEY;
		$GTOOLSUI::TAG{'<!-- PRT -->'} = $PRT;
		$GTOOLSUI::TAG{'<!-- ENABLE -->'} = ($NSREF->{'powerreviews:enable'})?'checked':'';
		$GTOOLSUI::TAG{'<!-- MERCHANTID -->'} = &ZOOVY::incode($NSREF->{'powerreviews:merchantid'});
		$GTOOLSUI::TAG{'<!-- GROUPID -->'} = &ZOOVY::incode($NSREF->{'powerreviews:groupid'});
	
		$template_file = 'powerreviews.shtml';
		push @BC, { name=>'PowerReviews' };
		}
	
	##
	##
	##
	if ($VERB eq 'MSNADCENTER-SAVE') {
		$NSREF->{'msnad:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$NSREF->{'msnad:chkoutjs'} = $ZOOVY::cgiv->{'head_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved MSNADCENTER plugin code","SAVE");
		$VERB = 'MSNADCENTER';
		}
	
	if ($VERB eq 'MSNADCENTER') {
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'msnad:chkoutjs'});
		if ($NSREF->{'msnad:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'msnad:filter'})?'checked':'';
		$template_file = 'msnadcenter.shtml';
		push @BC, { name=>'MSN' };
		}
	
	##
	##
	##
	if ($VERB eq 'NEXTAG-SAVE') {
		$NSREF->{'nextag:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'nextag:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved NEXTAG plugin code","SAVE");
		$VERB = 'NEXTAG';
		}
	
	if ($VERB eq 'NEXTAG') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'nextag:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'nextag:filter'})?'checked':'';
	
		if ($NSREF->{'nextag:chkoutjs'} =~ /\<\%order_total\%\>/) {
			push @WARNINGS, "Default variable: \<\%order_total\%\>";
			}
		if ($NSREF->{'nextag:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
	
		$template_file = 'nextag.shtml';
		push @BC, { name=>'NexTag' };
		}
	
	
	##
	##
	##
	if ($VERB eq 'PRICEGRABBER-SAVE') {
		$NSREF->{'pgrabber:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'pgrabber:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved PRICEGRABBER plugin code","SAVE");
		$VERB = 'PRICEGRABBER';
		}
	
	if ($VERB eq 'PRICEGRABBER') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'pgrabber:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'pgrabber:filter'})?'checked':'';
		if ($NSREF->{'pgrabber:chkoutjs'} =~ /a\|b\|c\|d\|e\|f/) {
			push @WARNINGS, "a|b|c|d|e|f are examples intended for use by programmers.";
			}
		if ($NSREF->{'pgrabber:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'pricegrabber.shtml';
		push @BC, { name=>'PriceGrabber' };	
		}
	
	##
	## 
	##
	if ($VERB eq 'CJ-SAVE') {
		$NSREF->{'cj:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'cj:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved CJ plugin code","SAVE");
		$VERB = 'CJ';
		}
	
	if ($VERB eq 'CJ') {
	
		push @BC, { name=>'Commission Junction' };	
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'cj:chkoutjs'});
		if ($NSREF->{'cj:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'cj:filter'})?'checked':'';
		$template_file = 'cj.shtml';
		}
	
	
	##
	## 
	##
	if ($VERB eq 'OMNISTAR-SAVE') {
		$NSREF->{'omnistar:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'omnistar:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved OMNISTAR plugin code","SAVE");
		$VERB = 'OMNISTAR';
		}
	
	if ($VERB eq 'OMNISTAR') {
	
		push @BC, { name=>'Omnistar' };	
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'omnistar:chkoutjs'});
		if ($NSREF->{'omnistar:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'omnistar:filter'})?'checked':'';
		$template_file = 'omnistar.shtml';
		}
	
	
	
	##
	## 
	##
	if ($VERB eq 'KOWABUNGA-SAVE') {
		$NSREF->{'kowabunga:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved KOWABUNGA plugin code","SAVE");
		$VERB = 'KOWABUNGA';
		}
	
	if ($VERB eq 'KOWABUNGA') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'kowabunga:chkoutjs'});
		if ($NSREF->{'kowabunga:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'kowabunga.shtml';
		push @BC, { name=>'Kowabunga' };
		}
	
	##
	## 
	##
	if ($VERB eq 'BIZRATE-SAVE') {
		$NSREF->{'bizrate:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'bizrate:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved BIZRATE plugin code","SAVE");
		$VERB = 'BIZRATE';
		}
	
	if ($VERB eq 'BIZRATE') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'bizrate:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'bizrate:filter'})?'checked':'';
	
		if ($NSREF->{'bizrate:chkoutjs'} =~ /PUT_YOUR_DATA_HERE/) {
			push @WARNINGS, "PUT_YOUR_DATA_HERE is not a valid variable.";
			}
		if ($NSREF->{'bizrate:chkoutjs'} =~ /\%OrderID\%/) {
			push @WARNINGS, "%OrderID% is not a valid Zoovy variable, you probably meant to customize this.";
			}
		if ($NSREF->{'bizrate:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'bizrate.shtml';
		push @BC, { name=>'BizRate' };
		}
	
	
	
	##
	## 
	##
	if ($VERB eq 'PRONTO-SAVE') {
		$NSREF->{'pronto:chkoutjs'} = $ZOOVY::cgiv->{'checkout_code'};
		$NSREF->{'pronto:filter'} = int(defined $ZOOVY::cgiv->{'filter'});
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved PRONTO plugin code","SAVE");
		$VERB = 'PRONTO';
		}
	
	if ($VERB eq 'PRONTO') {
		$GTOOLSUI::TAG{'<!-- CHECKOUT_CODE -->'} = &ZOOVY::incode($NSREF->{'pronto:chkoutjs'});
		$GTOOLSUI::TAG{'<!-- CHK_FILTER -->'} = ($NSREF->{'pronto:filter'})?'checked':'';
	
		if ($NSREF->{'pronto:chkoutjs'} =~ /PUT_YOUR_DATA_HERE/) {
			push @WARNINGS, "PUT_YOUR_DATA_HERE is not a valid variable.";
			}
		if ($NSREF->{'pronto:chkoutjs'} =~ /\<\%ORDERID\%\>/i) {
			push @WARNINGS, "&lt;%ORDERID%&gt; is not a valid Zoovy variable, you probably meant to customize this.";
			}
		if ($NSREF->{'pronto:chkoutjs'} =~ /\<\%SUBTOTAL\%\>/i) {
			push @WARNINGS, "&lt;%SUBTOTAL%&gt; is not a valid Zoovy variable, you probably meant to customize this.";
			}
	
	
		if ($NSREF->{'pronto:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$template_file = 'pronto.shtml';
		push @BC, { name=>'Pronto' };
		}
	
	
	
	##
	##
	##
	if ($VERB eq 'GOOGLEAW-SAVE') {
		$NSREF->{'googleaw:chkoutjs'} = $ZOOVY::cgiv->{'head_code'};
		$D->from_legacy_nsref($NSREF); $D->save();
		$LU->log("SETUP.PLUGIN","Saved GOOGLEAW plugin code","SAVE");
		$VERB = 'GOOGLEAW';
		}
	
	if ($VERB eq 'GOOGLEAW') {
		if ($NSREF->{'googleaw:chkoutjs'} =~ /http:/) {
			push @WARNINGS, $::WARN_INSECURE_CHKOUT_REFERENCE;
			}
		$GTOOLSUI::TAG{'<!-- HEAD_CODE -->'} = &ZOOVY::incode($NSREF->{'googleaw:chkoutjs'});
		$template_file = 'googleaw.shtml';
		$help = 50595;
		push @BC, { name=>'GoogleAdwords' };
		}
	
	
	
	
	##
	##
	##
	if ($VERB eq 'UPIC-SAVE') {
		$VERB = 'UPIC';
	
		## Syndication isn't setup to support PRTs yet
		#tie my %s, 'SYNDICATION', THIS=>$so;
		#$s{'.userid'} =  $ZOOVY::cgiv->{'userid'};
		## $s{'.pass'} =  $ZOOVY::cgiv->{'pass'};
		#$s{'IS_ACTIVE'} = int($ZOOVY::cgiv->{'enable'});
	
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		$webdb->{'upic'} = int($ZOOVY::cgiv->{'enable'});
		$webdb->{'upic_userid'} = $ZOOVY::cgiv->{'userid'};
		&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$PRT);
	
		#untie %s;
		#$so->save();
		$LU->log("SETUP.PLUGIN","Saved UPIC plugin code ($webdb->{'upic'})","SAVE");
		}
	
	if ($VERB eq 'UPIC') {
		$template_file = 'upic.shtml';
		## NOTE: at this point upic is NOT partition aware.
	
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		## Syndication isn't setup to support PRTs yet
		#tie my %s, 'SYNDICATION', THIS=>$so;
	
		$GTOOLSUI::TAG{'<!-- CHK_ENABLE_0 -->'} = ($webdb->{'upic'}==0)?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHK_ENABLE_1 -->'} = ($webdb->{'upic'}==1)?'checked':'';
		$GTOOLSUI::TAG{'<!-- USERID -->'} = (defined $webdb->{'upic_userid'})?$webdb->{'upic_userid'}:'';
		# $GTOOLSUI::TAG{'<!-- USERID -->'} = (defined $s{'.userid'})?$s{'.userid'}:'';
		# $GTOOLSUI::TAG{'<!-- PASS -->'} = (defined $s{'.pass'})?$s{'.pass'}:'';
		#$GTOOLSUI::TAG{'<!-- STATUS -->'} = $so->statustxt();
		
		if ($webdb->{'upic'}==0) {
			push @MSGS, "WARN|UPIC is disabled";
			}
		elsif ($webdb->{'upic_userid'} eq '') {
			push @MSGS, "WARN|No UPIC userid specified";
			}
		else {
			push @MSGS, "SUCCESS|UPIC is enabled, UPIC may download your order history.";
			}
	
		push @BC, { name=>'UPIC Insurance' };
		}
	
	
	
	
	
	##
	##
	##
	
	#if (($VERB eq 'BUYSAFE-SAVE') || ($VERB eq 'BUYSAFE-REFRESH')) {
	#
	#	#require PLUGIN::BUYSAFE;
	#	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	#	$webdbref->{'buysafe_mode'} = $ZOOVY::cgiv->{'buysafe_mode'};
	#	$webdbref->{'buysafe_token'} = $ZOOVY::cgiv->{'buysafe_token'};
	#	$webdbref->{'buysafe_sealhtml'} = $ZOOVY::cgiv->{'buysafe_sealhtml'};
	#	&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
	#
	#	if ($VERB eq 'BUYSAFE-REFRESH') {
	#		## 
	#		}
	#
	#	my $errcount = 0;
	#	my @domains = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
	#	foreach my $name (@domains) {
	#		my ($changed) = 0;
	#		my ($d) = DOMAIN->new($USERNAME,$name);
	#
	#		if (($d->{'BUYSAFE_TOKEN'} eq '') && ($VERB eq 'BUYSAFE-REFRESH')) {
	#			## they want us to get new tokens
	#			($d->{'BUYSAFE_TOKEN'},my $err) = &PLUGIN::BUYSAFE::AddStore($USERNAME,$PRT,$name);
	#			if ($err) {
	#				push @MSGS, "ERROR|BUYSAFE API ERROR [$name] token:".$d->{'BUYSAFE_TOKEN'}." Error: $err";
	#				$errcount++;
	#				}
	#			else {
	#				$changed++;
	#				}
	#			}
	#		elsif ($d->{'BUYSAFE_TOKEN'} ne $ZOOVY::cgiv->{$name}) {
	#			$d->{'BUYSAFE_TOKEN'} = $ZOOVY::cgiv->{$name};
	#			$changed++;
	#			}
	#	
	#		if ($changed) {
	#			$d->save();
	#			}
	#		}
	#
	#	my @domainrefs = &DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT,DETAIL=>1);
	#	foreach my $domain (@domainrefs) {
	#		my $profile = $domain->{'PROFILE'};
	#		if ($profile eq '') { $profile = 'DEFAULT'; }
	#		next if not (defined $ZOOVY::cgiv->{"profile:$profile"});
	#		my ($ref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$profile);
	#		$ref->{'zoovy:buysafe_sealhtml'} = $ZOOVY::cgiv->{"profile:$profile"};
	#		&ZOOVY::savemerchantns_ref($USERNAME,$profile,$ref);
	#		}
	#
	#	if ($errcount==0) {
	#		push @MSGS, "SUCCESS|Saved settings";
	#		}
	#	
	#	$LU->log("SETUP.PLUGIN","Saved BUYSAFE plugin code","SAVE");
	#	$VERB = 'BUYSAFE';
	#	}
	
	
	#my $tokensref = &BUYSAFE::loadTokens($USERNAME);
	#if ((not defined $tokensref) || (scalar keys %{$tokensref}==0)) {
	#	## Hmm.. they need to authenticate.
	#	
	
	#	$template_file = 'securekey.shtml';	
	#	}
	
	
	
	#if ($VERB eq 'BUYSAFE-AUTO') {
	#	## check to see if we need to do "BUYSAFE-NEW" or "BUYSAFE"
	#	$VERB = 'BUYSAFE';
	#	# my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	#	# if ($webdbref->{'buysafe_token'} eq '') { $VERB = 'BUYSAFE-NEW'; }
	#	}
	#
	##if ($VERB eq 'BUYSAFE-CREATE') {
	##	## 
	##	## Create a new buysafe user.
	##	##
	##	require BUYSAFE;
	##	my ($err) = &PLUGIN::BUYSAFE::AddAccount($USERNAME,$PRT);
	##	if ($err ne '') {
	##		$GTOOLSUI::TAG{'<!-- ERROR -->'} = "<font color='red'>ERROR:".&ZOOVY::incode($err)."</font><br><br>";
	##		$VERB = 'BUYSAFE-NEW';
	##		}
	##	else {
	##		$VERB = 'BUYSAFE';
	##		}
	##	}
	#
	##if ($VERB eq 'BUYSAFE-NEW') {
	##	## prompt the user to create an account.
	##	$template_file = 'buysafe-new.shtml';
	##	}
	
	
	
	#if (($VERB eq 'BUYSAFE') || ($VERB eq 'BUYSAFE-MANUAL')) {
	#	## let the user configure an existing account.
	#	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	#	my $buysafe_mode = $webdbref->{'buysafe_mode'};
	#	$GTOOLSUI::TAG{'<!-- BM_0 -->'} = ($buysafe_mode==0)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- BM_1 -->'} = ($buysafe_mode==1)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- BM_2 -->'} = ($buysafe_mode==2)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- BM_3 -->'} = ($buysafe_mode==3)?'selected':'';
	#	$GTOOLSUI::TAG{'<!-- BM_4 -->'} = ($buysafe_mode==4)?'selected':'';
	#
	#	$GTOOLSUI::TAG{'<!-- TOKEN -->'} = $webdbref->{'buysafe_token'};
	#	my @domains = DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
	#	my $c = '';
	#	foreach my $name (sort @domains) {
	#		my ($d) = DOMAIN->new($USERNAME,$name);
	#		$c .= "<tr>";
	#		$c .= "<td>$name</td>";
	#		if ($d->{'BUYSAFE_TOKEN'} eq '') {
	#			## no buysafe token
	#			$c .= "<td><i>No Token Set</i></td>";
	#			push @MSGS, "WARN|No token set for domain: $name (hint: use 'Update Tokens' button to correct.)";
	#			}
	#		else {
	#			$c .= "<td><input size=\"80\" type=\"textbox\" value=\"$d->{'BUYSAFE_TOKEN'}\" name=\"$name\"></td>";
	#			}
	#		$c .= "</tr>";
	#		}
	#	$GTOOLSUI::TAG{'<!-- DOMAINS -->'} = $c;
	#
	#	$c = '';
	#	my @domainrefs = &DOMAIN::TOOLS::domains($USERNAME,PRT=>$PRT);
	#	foreach my $domain (@domainrefs) {
	#		my ($D) = DOMAIN->new($USERNAME,$domain);
	#		my $profile = $D->{'PROFILE'};
	#		if ($profile eq '') { $profile = 'DEFAULT'; }
	#		my ($ref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$profile);
	#		$c .= "<tr>";
	#		$c .= "<td valign=top><b>DOMAIN: $D->{'DOMAIN'}<br>PROFILE: $profile</b></td>";
	#		$c .= "<td valign=top><textarea cols=70 rows=3 name=\"profile:$profile\">";
	#		$c .= &ZOOVY::incode($ref->{'zoovy:buysafe_sealhtml'})."</textarea><br>";
	#
	#		if (($buysafe_mode == 0) && ($ref->{'zoovy:sidebar_html'} =~ /buysafe/)) {
	#			## has buysafe in sidebar
	#			$c .= "<font color='red'>BUYSAFE IS CURRENTLY ADDED TO THEME SIDEBAR, BUT ZOOVY CART FUNCTIONALITY APPEARS TO BE DISABLED (THIS PROBABLY ISN'T WHAT YOU WANT).</font>";
	#			}
	#		elsif (($buysafe_mode>1) && ($ref->{'zoovy:sidebar_html'} =~ /buysafe/i)) {
	#			## has buysafe in sidebar
	#			my ($color) = ($ref->{'zoovy:buysafe_sealhtml'} eq '')?'red':'blue';
	#			$c .= "<font color='$color'>BUYSAFE IS ENABLED, AND CURRENTLY ADDED TO THEME SIDEBAR.</font>";
	#			}
	#		else {
	#			## no buysafe in sidebar
	#			my ($color) = ($ref->{'zoovy:buysafe_sealhtml'} eq '')?'red':'blue';
	#			if (($color eq 'blue') && ($buysafe_mode == 2)) { $color = 'red'; }
	#			$c .= "<font color='$color'>BUYSAFE HAS NOT BEEN ADDED TO THEME SIDEBAR.</font>";
	#			}
	#
	#		$c .= "</td>";
	#		$c .= "</tr>";
	#		}
	#	$GTOOLSUI::TAG{'<!-- PROFILES -->'} = $c;
	#
	#	my ($SECUREKEY) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'BS');
	#	$GTOOLSUI::TAG{'<!-- SECUREKEY -->'} = $SECUREKEY;
	#
	#	push @BC, { name=>'buySAFE Website Bonding' };
	#	$template_file = 'buysafe.shtml';
	#	}
	#
	
	
	if ($VERB eq '') {
	
		$GTOOLSUI::TAG{'<!-- CHKOUT_ROI_DISPLAY_HINT -->'} = ($WEBDB->{'chkout_roi_display'})?'Always (even on failure)':'Only on successful/pending payments';
	
	   #my $profref = &DOMAIN::TOOLS::syndication_profiles($USERNAME,PRT=>$PRT,'DOMAIN'=>$LU->domain());
	   #my $c = '';
	   #my $cnt = 0;
	   #foreach my $ns (sort keys %{$profref}) {
			## my ($NSREF) = &ZOOVY::fetchmerchantns_ref($USERNAME,$ns);
	
		my ($DOMAINNAME) = $D->domainname();
	
		my $c = '';
		if (1) {
			
	      ## my $class = ($cnt++%2)?'r0':'r1';
			my $class = 'r0';
	      $c .= "<tr><td class=\"zoovysub1header\" colspan=4 valign=top class=\"$class\">$DOMAINNAME</td></tr>";
			$c .= "<tr><td width=20 class=\"$class\">&nbsp;</td>";
			$c .= "<td width=260 valign=top class=\"$class\">";
			$c .= "<br><b>Trust &amp; Seals:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLETS&DOMAIN=$DOMAINNAME\">Google Trusted Stores</a><br>";
			$c .= "<br><b>SiteMap/Analytics:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLEAN&DOMAIN=$DOMAINNAME\">Google Analytics</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLEWMT&DOMAIN=$DOMAINNAME\">Google Webmaster/SiteMap</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=BINGWMT&DOMAIN=$DOMAINNAME\">Bing Webmaster/SiteMap</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=YAHOOWMT&DOMAIN=$DOMAINNAME\">Yahoo Site Explorer</a><br>";
			$c .= "<br><b>Affiliate Programs:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=SAS&DOMAIN=$DOMAINNAME\">Share-A-Sale</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=OMNISTAR&DOMAIN=$DOMAINNAME\">Omnistar</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=CJ&DOMAIN=$DOMAINNAME\">Commission Junction</a><br>";
			# $c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=RM&DOMAIN=$DOMAINNAME\">RazorMouth</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=KOWABUNGA&DOMAIN=$DOMAINNAME\">MyAffiliateProgram/MyAP/KowaBunga!</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=LINKSHARE&DOMAIN=$DOMAINNAME\">Linkshare.com</a><br>";
	
			$c .= "<br></td><td width=260 valign=top class=\"$class\">";
			$c .= "<br><b>Remarketing:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=VERUTA&DOMAIN=$DOMAINNAME\">Veruta</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=FETCHBACK&DOMAIN=$DOMAINNAME\">FetchBack</a><br>";
			$c .= "<br><b>ROI Tracking:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLEAW&DOMAIN=$DOMAINNAME\">Google Adwords</a><br>";
			# $c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=YAHOO&DOMAIN=$DOMAINNAME\">Yahoo Shopping / CPC</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=SHOPCOM&DOMAIN=$DOMAINNAME\">Shopping.com</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=BIZRATE&DOMAIN=$DOMAINNAME\">Shopzilla/BizRate</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=PRONTO&DOMAIN=$DOMAINNAME\">Pronto</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=MSNADCENTER&DOMAIN=$DOMAINNAME\">MSN AdCenter</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=NEXTAG&DOMAIN=$DOMAINNAME\">NexTag</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=PRICEGRABBER&DOMAIN=$DOMAINNAME\">Pricegrabber</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=BECOME&DOMAIN=$DOMAINNAME\">Become.com</a><br>";
	
			$c .= "<br></td><td width=260 valign=top class=\"$class\">";
			$c .= "<br><b>Customer Service/Relations:</b><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=FACEBOOK&DOMAIN=$DOMAINNAME\">Facebook</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=TWITTER&DOMAIN=$DOMAINNAME\">Twitter</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=POWERREVIEWS&DOMAIN=$DOMAINNAME\">PowerReviews</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=PROVIDESUPPORT&DOMAIN=$DOMAINNAME\">ProvideSupport Chat</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=OLARK&DOMAIN=$DOMAINNAME\">OLark Chat</a><br>";
			if ($NSREF->{'livechat:tracking'} ne '') {
				$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=LIVECHAT&DOMAIN=$DOMAINNAME\">LIVECHAT Software</a> (Deprecated)<br>";
				}
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=WISHPOT&DOMAIN=$DOMAINNAME\">Wishpot (Social Shopping &amp; Wishlist)</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=UPSELLIT&DOMAIN=$DOMAINNAME\">Upsellit</a><br>";
			$c .= "<br><b>Other/Non Supported:</b><br>";
	#		$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=DECALS&DOMAIN=$DOMAINNAME\">Website Decals</a><br>";
			$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=OTHER&DOMAIN=$DOMAINNAME\">Other: Non Supported Application</a><br>";
	#		$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=OMNITURE&DOMAIN=$DOMAINNAME\">Omniture SiteCatalyst / SilverPop</a><br>";
	#		$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLE&DOMAIN=$DOMAINNAME\">LivePerson</a><br>";
	#		$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLE&DOMAIN=$DOMAINNAME\">Kowabunga</a><br>";
	#		$c .= "- <a href=\"/biz/vstore/analytics/index.cgi?VERB=GOOGLE&DOMAIN=$DOMAINNAME\">SecondBite</a><br>";
	
			$c .= "<Br>";
			$c .= "</td></tr>";
	      }
	   $GTOOLSUI::TAG{'<!-- PROFILES -->'} = $c;
	   $template_file = 'index.shtml';
		}
	
	$GTOOLSUI::TAG{'<!-- DISCLAIMER -->'} = qq~
	<div>
	<table style="border:1px dotted #e4de7b; margin:10px 0; background:#FFFEED;  text-align:left;" width=600>
	<tr>
		<td><b>SUPPORT POLICY:</b></td>
	</tr>
	<tr>
		<td>
	<div class="hint">
	
	Access to this area is provided as a convenience to our clients.
	Zoovy does not provide standard implementation or technical support for javascript hosted by other companies per our 
	<a target="webdoc" href="http://www.zoovy.com/webdoc/index.cgi?VERB=DOC&DOCID=51375">3rd Party Javascript Policy</a>.
	
	Support Requests will be routed to our 
	<a target="webdoc" href="http://www.zoovy.com/webdoc/index.cgi?VERB=DOC&DOCID=51356">Marketing Services department</a>
	and will have a billable project created. 
	
	Programmers who plan to integrate services without assistance will most likely find the 
	<a target="webdoc" href="http://www.zoovy.com/webdoc/index.cgi?VERB=DOC&DOCID=51020">Analytics/ROI Javascript Developer Documentation</a>
	invaluable.  
	
	By choosing to deploy code into this area you agree that you have been informed it is both possible, and easy to 
	break your site in a variety of colorful and non-obvious ways, and that on higher traffic sites it can also impact our 
	servers - therefore you also accept that any resources necessary to identify and correct associated problems 
	will be charged back to your account. 
	
	Clients who participate in our 
	<a target="webdoc" href="http://www.zoovy.com/webdoc/index.cgi?VERB=DOC&DOCID=50849">Best Partner Practices</a>
	program are required to utilize Zoovy marketing services.
	
		</td>
	</tr>
	</table>
	</div>
	~;
	foreach my $warning (@WARNINGS) {
		$GTOOLSUI::TAG{'<!-- DISCLAIMER -->'} .= qq~
	<table width=600><tr><td><div class="warning">
	<b>WARNING:</b> $warning<br>
	</div>
	</td></tr></table>
	~;	
		}
	$GTOOLSUI::TAG{'<!-- DISCLAIMER -->'} .= '<br>';
	
	
	##
	##
	return(
		title=>"Analytics and Plugins",
		file=>$template_file,
		js=>2+4,
		help=>$help,
		bc=>\@BC,
		msgs=>\@MSGS,
		tabs=>\@TABS,
		header=>1
		);
	}



##
##
##

sub toxml {
	my ($JSONAPI,$cgiv) = @_;
	$ZOOVY::cgiv = $cgiv;

	my ($LU) = $JSONAPI->LU();
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();

	my @MSGS = ();
	push @MSGS, "WARN|REMINDER: VStore end-of-life is January 1st, 2015.";

	push @MSGS, "LEGACY|June 2012 Deprecation Notice: the TOXML format is being sunsetted on or after Jan 1st, 2015
	
	Technical support for this format has ended.
	Originally developed for compatibility with HTML 3.0 - the toxml format itself will be over 15 years old (<i>thats 6 years older than CSS is</i>), and it's past-due for a fresh clean start. 
	We are building sites based on the AnyCommerce Javascript(jQuery) Application Framework, which is a pure CSS3+HTML+Javascript approach for building dynamic websites and mobile applications.
	The source code is hosted on github and can quickly be forked, customized, and then an application project can be  in Setup / Projects which automatically updates from the github repository after a commit 
	(making updates VERY fast and painless) in addition to giving painless version tracking, and awesome rollback capabilities normally associated
	with github.  To put it bluntly - it's an absolute joy to work with.
	Zoovy backends are 100% compatible with the AnyCommerce App framework. 
	It takes a typical web-developer about 10 hours to learn the AnyCommerce App Framework.
	";

	my @TABS = ();
	## determine tabs available 	
	## WEB flag should see layout and wrapper tabs
	if (index($FLAGS,',WEB,') > 0 ) {
		push @TABS, { name=>'Wrappers', link=>'/biz/vstore/toxml/index.cgi?FORMAT=WRAPPER', },
						{ name=>'Layouts', link=>'/biz/vstore/toxml/index.cgi?FORMAT=LAYOUT', },
						{ name=>'Emails', link=>'/biz/vstore/toxml/index.cgi?FORMAT=ZEMAIL', };
		}
	## EBAY flag should see the wizard tab
	if (index($FLAGS,',EBAY,') > 0 ) {
		push @TABS, { name=>'Wizards', link=>'/biz/vstore/toxml/index.cgi?FORMAT=WIZARD', };
		}
	
	## no authorization to edit TOXML
	push @TABS, { name=>'Help', link=>'/biz/vstore/toxml/index.cgi?ACTION=HELP', };
	
	if ($LU->is_zoovy()) {
	   push @TABS, { 'name'=>'New Wrapper', link=>'/biz/vstore/toxml/index.cgi?ACTION=NEW&FORMAT=WRAPPER' };
	   push @TABS, { 'name'=>'New Layout', link=>'/biz/vstore/toxml/index.cgi?ACTION=NEW&FORMAT=LAYOUT' };
	   push @TABS, { 'name'=>'New Layout', link=>'/biz/vstore/toxml/index.cgi?ACTION=NEW&FORMAT=ZEMAIL' };
	   }
	
	my $ACTION = $ZOOVY::cgiv->{'ACTION'};
	print STDERR "ACTION: $ACTION\n";
	
	
	my $FORMAT = $ZOOVY::cgiv->{'FORMAT'};
	if ($ACTION eq 'DOWNLOAD') {
	   }
	elsif ($ACTION eq 'NEW') {
	   }
	elsif ($FORMAT eq '') { 
	   $ACTION = ''; 
	   }	
	
	my $DOCID = $ZOOVY::cgiv->{'DOCID'};
	
	#print "Content-type: text/plain\n\n"; print Dumper($ZOOVY::cgiv,$ACTION); die();
	
	## choices from top page
	if ($ACTION eq "Edit XML") {	
		&ZWEBSITE::save_website_attrib($USERNAME,'pref_template_fmt',uc($ZOOVY::cgiv->{'TYPE'}));
		if ($ZOOVY::cgiv->{'TYPE'} eq "xml") { $ACTION = "EDITXML"; }
		elsif ($ZOOVY::cgiv->{'TYPE'} eq "html") { $ACTION = "EDITHTML"; }
		# elsif ($ZOOVY::cgiv->{'TYPE'} eq "plugin") { $ACTION = "EDITPLUGIN"; }
		else { $ACTION = ''; $GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "Please choose a File Format ".$ZOOVY::cgiv->{'TYPE'}; } 
		}
	
	$GTOOLSUI::TAG{'<!-- FORMAT -->'} = $FORMAT;
	
	my $template_file = 'index.shtml';
	my $header = 1;
	
	
	print STDERR "ACTION=$ACTION FORMAT=$FORMAT DOCID=$DOCID\n";
	
	
	my @BC = ();
	push @BC, 	{ name=>'Setup',link=>'/biz/vstore','target'=>'_top', },
	      	 	{ name=>'Template Manager',link=>'/biz/vstore/toxml/index.cgi?ACTION=HELP','target'=>'_top', };
	    
	
	
	
	if (($ACTION eq 'EDITXML') || ($ACTION eq 'NEW')) {
		$GTOOLSUI::TAG{'<!-- DOCID -->'} = $DOCID;
			
		$DOCID = '*'.$DOCID;
		my ($toxml) = TOXML->new($FORMAT,$DOCID,USERNAME=>$USERNAME,MID=>$MID);
		my ($cfg) = $toxml->findElements('CONFIG');
	
		if ($LU->is_zoovy()) { $cfg->{'EXPORT'} = 1; }
		if ($ACTION eq 'EDITXML') {
			$GTOOLSUI::TAG{'<!-- AS_TYPE -->'} = ' as Strict XML';
			$GTOOLSUI::TAG{'<!-- CONTENT -->'} = &ZOOVY::incode($toxml->as_xml());
			}
	
		$template_file = 'edit.shtml';
		}
	
	
	if ($ACTION eq 'SAVEAS') {
		## when the user does a raw edit.
		# load the flow style
		my ($CTYPE,$FLAGS,$SHORTNAME,$LONGNAME) = ();
	
		$DOCID =~ s/[^\w\-\_]+//gs;
		if ($DOCID eq '') { $DOCID = 'unnamed_'.time(); }
		$DOCID = '*'.$DOCID;
		
	   open F, ">/tmp/content";
	   print F Dumper($ZOOVY::cgiv);
	   close F;
		
		my $content = '';
	 	if (not defined $ZOOVY::cgiv->{'CONTENT'}) {
			my $ORIGDOCID = $ZOOVY::cgiv->{'ORIGDOCID'};
			my ($toxml) = TOXML->new($FORMAT,$ORIGDOCID,USERNAME=>$USERNAME,MID=>$MID);
	
			if (defined $toxml) { $content = $toxml->as_xml(); }
			else { warn("TOXML Could not load $FORMAT, $DOCID,USERNAME=>$USERNAME,MID=>$MID\n"); }
	
			my ($cfg) = $toxml->findElements('CONFIG');
			#if ((defined $cfg->{'EXPORT'}) && ($cfg->{'EXPORT'}==0)) {
			#	$content = $::DENIEDMSG;
			#	}
			}
		else {
			$content = $ZOOVY::cgiv->{'CONTENT'};
			}
		
		$GTOOLSUI::TAG{'<!-- DOCID -->'} = $DOCID;
	
		my $toxml = undef;
		eval { ($toxml) = TOXML::COMPILE::fromXML($FORMAT,$DOCID,$content,USERNAME=>$USERNAME,MID=>$MID); };
		if (defined $toxml) {
			$LU->log("SETUP.TOXML","Edited TOXML file FORMAT=$FORMAT DOCID=$DOCID","SAVE");
			$toxml->save(LUSER=>$LUSERNAME);
			$DOCID = $toxml->docId();
			print STDERR "saving toxml: $DOCID as a $FORMAT\n";
	      push @MSGS, "SUCCESS|+successfully saved DOCID[$DOCID] FORMAT[$FORMAT]";
			}
		else {
	      push @MSGS, "ERROR|+could not save $DOCID (please check formatting)";
			}
		$ACTION = '';
		}
	
	
	if ($ACTION eq 'DOWNLOAD') {
		my $DOCID = $ZOOVY::cgiv->{'DOCID'};
		$GTOOLSUI::TAG{'<!-- DOCID -->'} = $DOCID;
	
		my ($toxml) = TOXML->new($FORMAT,$DOCID,USERNAME=>$USERNAME,MID=>$MID);
		my $cfg = undef;
		my ($cfg) = $toxml->findElements('CONFIG');
		my $content = '';
		
		$content = &ZOOVY::incode($toxml->as_xml());
		$content =~ s/[\n\r]+/<br>/g;
		$content =~ s/&lt;ELEMENT/<font color='blue'>&lt;ELEMENT/gs;
		$content =~ s/\/ELEMENT&gt;/\/ELEMENT&gt;<\/font>/gs;
	
		$GTOOLSUI::TAG{'<!-- CONTENT -->'} = $content;
		$template_file = 'output.shtml';
		}
	
	if ($ACTION eq 'DELETE') {
		my $DOCID = $ZOOVY::cgiv->{'DOCID'};
		my ($toxml) = TOXML->new($FORMAT,$DOCID,USERNAME=>$USERNAME,MID=>$MID);
		$toxml->nuke();
		$LU->log("SETUP.TOXML","Confirmed deletion of DOCTYPE:$FORMAT DOC:$DOCID","NUKE");
		
		$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "Removed $DOCID\n";
		$ACTION = '';
		}
	
	
	print STDERR "ACTION: $ACTION\n";
	if ($ACTION eq 'ACKDELETE') {
		$GTOOLSUI::TAG{'<!-- DOCID -->'} = $ZOOVY::cgiv->{'DOCID'};
		$template_file = 'confirmdelete.shtml';
		}
	
	
	if ($ACTION eq 'TOP') {
		my $c = '';
		foreach my $k (sort keys %{$TOXML::UTIL::LAYOUT_STYLES}) {
			my $short = $TOXML::UTIL::LAYOUT_STYLES->{$k}[0];
			my $long = $TOXML::UTIL::LAYOUT_STYLES->{$k}[1];
			$c .= "<option value='$k'>$short</option>";
		}
		$GTOOLSUI::TAG{'<!-- FLOWSTYLE -->'} = $c;
	
		## Load the custom theme list.
		$c = '';
		my $arref = &TOXML::UTIL::listDocs($USERNAME,$FORMAT,DETAIL=>1);
		foreach my $inforef (@{$arref}) {
			next unless ($inforef->{'MID'}>0); 
			print STDERR Dumper($inforef);
	
			my $k = $inforef->{'DOCID'};
			my $name = $inforef->{'TITLE'};	
	
			# only look at userland flows
			$c .= "<a href='/biz/vstore/toxml/index.cgi?ACTION=EDITXML&DOCID=".CGI->escape($k)."'>[EDIT XML]</a> ";
			$c .= "<a href='/biz/vstore/toxml/index.cgi?ACTION=ACKDELETE&DOCID=".CGI->escape($k)."'>[REMOVE]</a> ($k) $name<br>\n";
			}
		if ($c eq '') { $c = '<i>None</i>'; }
		$GTOOLSUI::TAG{'<!-- EXISTINGFLOWS -->'} = $c;
	
		## Load the full theme list for the select boxetemplates
		my $arref = &TOXML::UTIL::listDocs($USERNAME,$FORMAT,DETAIL=>1);
		$c = '';
		foreach my $inforef (reverse @{$arref}) {
			# only look at userland flows
			my $DOCID = $inforef->{'DOCID'};
			my $SUBTYPE = $inforef->{'SUBTYPE'};
			my $SUBTYPETXT = $TOXML::UTIL::LAYOUT_STYLES->{$SUBTYPE}[0];
			$c .= "<option value=\"$DOCID\">[$DOCID] $SUBTYPETXT: $inforef->{'TITLE'}</option>\n";
			}
		undef $arref;
		$GTOOLSUI::TAG{'<!-- ALLLAYOUTS -->'} = $c;
		
		$template_file = 'top.shtml';
		}
	
	## Display top page for managing each FORMAT
	if ($ACTION eq 'HELP') {
		$template_file = 'index.shtml';
		}
	
	##
	## saves theme and button settings into the wrapper (by physically modifying the wrapper)
	##
	if ($ACTION eq 'SAVE-SITEBUTTONS') {
		# Saves the site buttons and theme for a wrapper
		require TOXML::UTIL;
	
		my ($toxml) = TOXML->new('WRAPPER',$DOCID,USERNAME=>$USERNAME,MID=>$MID);
		my ($configel) = $toxml->findElements('CONFIG');
	
		my $sbtxt = $ZOOVY::cgiv->{'sitebuttons'};
		if ($sbtxt eq '') { $sbtxt = $ZOOVY::cgiv->{'sitebuttons_txt'}; }	
		if ($sbtxt eq '') { $sbtxt = 'default'; } ## yipes!?!?
	
		if (index($sbtxt,'|')==-1) {
			## passing an old button reference, lets load it out of info.txt
			$sbtxt =~ s/[^a-z0-9\_]+//gs;	# strip bad characters
			if (open F, "</httpd/static/sitebuttons/$sbtxt/info.txt") {
				$/ = undef; $sbtxt = <F>; $/ = "\n";
				close F;
				}
			}
		$configel->{'SITEBUTTONS'} = $sbtxt;
		$toxml->save(LUSER=>$LUSERNAME);
	   push @MSGS, "SUCCESS|+Successfully saved sitebuttons";
	
		$ACTION = '';	
		$FORMAT = 'WRAPPER';
		}
	
	
	
	##
	## Gives the user an editor for the site buttons and theme associated with a wrapper
	##
	if ($ACTION eq 'SITEBUTTONS') {
	
		my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT,'DOMAIN'=>$LU->domainname());
	
		require TOXML::UTIL;
		my ($toxml) = TOXML->new('WRAPPER',$DOCID,USERNAME=>$USERNAME,MID=>$MID);
		my ($config) = $toxml->initConfig($SITE);
		my ($configel) = $toxml->findElements('CONFIG');
	
		$GTOOLSUI::TAG{'<!-- DOCID -->'} = $DOCID;	
		my $out = '';
		my $c = '';
	
		$GTOOLSUI::TAG{'<!-- BUTTON_PREVIEW -->'} = "<tr>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'add_to_cart'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'continue_shopping'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'update_cart'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'back'},$toxml)."</td>".
			"</tr><tr>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'cancel'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'empty_cart'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'checkout'},$toxml)."</td>".
			"<td>".&TOXML::RENDER::RENDER_SITEBUTTON({'TYPE'=>'BUTTON',BUTTON=>'forward'},$toxml)."</td>".
			"</tr>";
			
		$GTOOLSUI::TAG{'<!-- SITEBUTTONS_TXT -->'} = $configel->{'SITEBUTTONS'};
		if (open SITEBUTTONS, "</httpd/static/sitebuttons.txt") {
			while (<SITEBUTTONS>) {
				my ($code, $name, $format) = split(/\t/,$_,3);
				if ($name eq '') { $name = $code; }
				if ($format eq '') { $format = 'gif'; }
	
					$c .= qq~
				<tr>
					<td><input type="radio" name="sitebuttons" value="$code"></td>
					<td>$name</td>
					<td><img src="http://proshop.zoovy.com/graphics/sitebuttons/$code/add_to_cart.$format"></td>
					<td><img src="http://proshop.zoovy.com/graphics/sitebuttons/$code/update_cart.$format"></td>
				</tr>
				~;
				}
			}
	
		$GTOOLSUI::TAG{'<!-- BUTTON_LIST -->'} = $c;
		$template_file = 'wrapper-site-buttons.shtml';
		}
	
	
	
	
	
	
	if ($ACTION eq '') {
		$template_file = "modes.shtml";
	
		my $pretty = lc($FORMAT);
		if ($FORMAT eq '') { $pretty = 'templates'; }
		$pretty =~ s/_/ /g;
		$GTOOLSUI::TAG{'<!-- FORMAT_PRETTY -->'} = ucfirst($pretty);
	
		## Load the full theme list.
		my $c = '';
		my $z = '';
		## BLANK LISTS ALL
		my $arref = &TOXML::UTIL::listDocs($USERNAME,$FORMAT,DETAIL=>1);
		my $ctr =0;
	
		my $c_row = "r0";  #tables.css alternates the class on the row between r0 and r1.
	   my $z_row = "r0";
	
		foreach my $inforef (sort @{$arref}) {
			$ctr++;
			#last if $ctr > 20;
			#print STDERR Dumper($inforef);
			my $TITLE = $inforef->{'TITLE'};
			if ($TITLE eq '') { $TITLE = '<i>Title Not Set</i>'; }
			my $DOCID = $inforef->{'DOCID'};
			my $SUBTYPE = $inforef->{'SUBTYPE'};
			my $SUBTYPETXT = $TOXML::UTIL::LAYOUT_STYLES->{$SUBTYPE}[0];
	
			#my $configel = TOXML::just_config_please($USERNAME,$FORMAT,$DOCID);		
			my ($MID) = &ZOOVY::resolve_mid($USERNAME);
			my ($t) = TOXML->new($inforef->{'FORMAT'},"$DOCID",USERNAME=>$USERNAME,MID=>$MID);
			my $configel = undef;
			if (defined $t) {
				($configel) = $t->findElements('CONFIG');	# fetch the first CONFIG element out of the document.	
				}
	
			## CUSTOM TOXML
			if ($inforef->{'MID'}>0) {
				# only look at userland flows
	
				my $pref_fmt = &ZWEBSITE::fetch_website_attrib($USERNAME,'pref_template_fmt');
				my $html_checked = ($pref_fmt eq 'HTML')?'checked':'';
				my $xml_checked = ($pref_fmt eq 'XML')?'checked':'';
				# my $plugin_checked = ($pref_fmt eq 'PLUGIN')?'checked':'';
	
				$c .= qq~
						<tr class="$c_row">
							<td>$inforef->{'FORMAT'}.$DOCID
								<a href="/biz/vstore/toxml/index.cgi?ACTION=ACKDELETE&FORMAT=$FORMAT&DOCID=$DOCID">
								<font color=red size="-3"><i>(remove)</i></font></a></td>
							<td>$TITLE</td> 
							<td align="right" nowrap>
								<button onClick="navigateTo('/biz/vstore/toxml/index.cgi?ACTION=EDITXML&DOCID=$DOCID&FORMAT=$inforef->{'FORMAT'}&TYPE=xml'); return false;">Edit XML</button>
								~;
				$c .= qq~
						</td></tr>~;
				$c_row = ($c_row eq "r1")?"r0":"r1";
				}
	
			## Zoovy TOXML
			elsif ($DOCID eq '') {
				}
			else {
				$z .= qq~
						<tr class="$z_row">
							<td>$DOCID</td>
							<td>$TITLE</td>
							<td align="right" nowrap>
							<a href="/biz/vstore/toxml/index.cgi?ACTION=DOWNLOAD&FORMAT=$inforef->{'FORMAT'}&DOCID=$DOCID">[ View/Copy ]</a></td>
						</tr>~;
				$z_row = ($z_row eq "r1")?"r0":"r1";
				}			
			}
	
		if ($c eq '') { $c = '<i>None</i>'; }
		if ($z eq '') { $z = '<i>None</i>'; }
		
		$GTOOLSUI::TAG{'<!-- CUSTOM_TOXML -->'} = $c;
		$GTOOLSUI::TAG{'<!-- ZOOVY_TOXML -->'} = $z;
	
		undef $arref;
		}
	
	
	
	return(
		'base'=>'toxml',
	   'title'=>'Setup : TOXML Manager',
	   'file'=>$template_file,
	   'header'=>1,
		'msgs'=>\@MSGS,
	   'help'=>'#50156',
	   'tabs'=>\@TABS,
	   'bc'=>\@BC,
	   );
	
	}






##
##
##

sub advwebsite {
	my ($JSONAPI,$cgiv) = @_;

	$ZOOVY::cgiv = $cgiv;
	my ($LU) = $JSONAPI->LU();

	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	if ($MID<=0) { exit; }
	
	if ($USERNAME eq '') { exit; }
	
	$GTOOLSUI::TAG{'<!-- USERNAME -->'} = $USERNAME;
	my $VERB = $ZOOVY::cgiv->{'MODE'};
	if ($VERB eq '') { $VERB = 'GENERAL'; }
	
	my $ACTION = $ZOOVY::cgiv->{'ACTION'};
	my $HELP = '';
	
	
	my $template_file = '';
	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	
	my @MSGS = ();
	push @MSGS, "WARN|REMINDER: VStore end-of-life is January 1st, 2015.";
	
	if (my @FAILURES = $LU->acl_require('CONFIG'=>['R','U'])) {
		foreach my $msg (@FAILURES) {	push @MSGS, "DENY|$msg"; }
		$VERB = 'DENY';
	   $template_file = '_/denied.shtml';
		}
	
	if ($VERB eq 'CUSTOMERADMIN-SAVE') {
		
		$webdbref->{"order_status_notes_disable"} = (defined $ZOOVY::cgiv->{'order_status_notes_disable'})?1:0;
		$webdbref->{"order_status_disable_login"} = (defined $ZOOVY::cgiv->{'order_status_disable_login'})?1:0;
		$webdbref->{"order_status_hide_events"} = (defined $ZOOVY::cgiv->{'order_status_hide_events'})?1:0;
		$webdbref->{'order_status_reorder'} = (defined $ZOOVY::cgiv->{'order_status_reorder'})?1:0;
		$webdbref->{"disable_cancel_order"} = (defined $ZOOVY::cgiv->{'disable_cancel_order'})?1:0;
		$LU->log("SETUP.CHECKOUT.CUSTOMER","Updated Customer Admin Settings","SAVE");
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		$VERB = 'CUSTOMERADMIN';
		}
	
	if ($VERB eq 'CUSTOMERADMIN') {
		$template_file = 'customeradmin.shtml';
		my $c = '';
	
	
		$GTOOLSUI::TAG{'<!-- ORDER_STATUS_NOTES_DISABLE -->'} = ($webdbref->{"order_status_notes_disable"})?'checked':'';
		$GTOOLSUI::TAG{"<!-- ORDER_STATUS_DISABLE_LOGIN_CHECKED -->"} = ($webdbref->{"order_status_disable_login"}) ? 'checked':'';
		$GTOOLSUI::TAG{"<!-- ORDER_STATUS_HIDE_EVENTS_CHECKED -->"} = ($webdbref->{"order_status_hide_events"}) ? 'checked':'';
		$GTOOLSUI::TAG{'<!-- ORDER_STATUS_REORDER -->'} = ($webdbref->{'order_status_reorder'})?'checked':'';
		$GTOOLSUI::TAG{"<!-- DISABLE_CANCEL_ORDER -->"} = ($webdbref->{"disable_cancel_order"}) ? 'checked':'';
	
		$GTOOLSUI::TAG{'<!-- HEADER_PANELS -->'} = $c;	
		}
	
	
	
	if ($VERB eq 'INTERNATIONAL') {
		## 
		my ($prtinfo) = &ZWEBSITE::prtinfo($USERNAME,$PRT);
		
		my %currency = ( 'USD'=>1 );
		my %language = ( 'ENG'=>1 );
		if ($ACTION eq 'INTERNATIONAL-SAVE') {
			foreach my $x (keys %{$ZOOVY::cgiv}) {
				if ($x =~ /C\*(.*?)$/) { $currency{uc($1)}++; }
				if ($x =~ /L\*(.*?)$/) { $language{uc($1)}++; }			
				}
			$currency{'USD'}++;
			$language{'ENG'}++;
	
			$prtinfo->{'currency'} = join(',', sort keys %currency);
			$prtinfo->{'language'} = join(',', sort keys %language);
			&ZWEBSITE::prtsave($USERNAME,$PRT,$prtinfo);
			}
	
		foreach my $cur (split(',',$prtinfo->{'currency'})) { $currency{$cur}++; }
		foreach my $lang (split(',',$prtinfo->{'language'})) { $language{$lang}++; }
	
		require SITE::MSGS;
		my $checked = ''; my $r = '';
		my $c = '';
		foreach my $cur (sort keys %SITE::MSGS::CURRENCIES) {
			my $curref = $SITE::MSGS::CURRENCIES{$cur};
			if (defined $currency{$cur}) { $r='rs'; $checked = ' checked '; } else { $r='r0'; $checked = ''; }
	
			$c .= "<tr class=\"$r\"><td><input type=\"checkbox\" $checked name=\"C*$cur\"></td><td>$cur</td><td>$curref->{'pretty'}</td><td>$curref->{'region'}</td></tr>";
			}
		$GTOOLSUI::TAG{'<!-- CURRENCIES -->'} = $c;
	
		$c = '';
		foreach my $lang (sort keys %SITE::MSGS::LANGUAGES) {
			my $langref = $SITE::MSGS::LANGUAGES{$lang};
			if (defined $language{$lang}) { $r = 'rs'; $checked = ' checked '; } else { $r='r0'; $checked = ''; }
			
			$c .= "<tr class=\"$r\"><td><input type=\"checkbox\" $checked name=\"L*$lang\"></td><td>$lang</td><td>$langref->{'pretty'}</td><td>$langref->{'in'}</td></tr>";
			}
		$GTOOLSUI::TAG{'<!-- LANGUAGES -->'} = $c;
	
	
		$template_file = 'international.shtml';
		}
	
	
	if ($VERB eq 'CREATE-MESSAGE') {
		require SITE::MSGS;
		my ($SM) = SITE::MSGS->new($USERNAME,RAW=>1,PRT=>$PRT);
	
		my $ERROR = '';
	
		my $MSGID = $ZOOVY::cgiv->{'ID'};
		if ($MSGID eq '') { $ERROR = "MSGID is blank"; }
		my $LANG = $ZOOVY::cgiv->{'LANG'};
		my $MSG = "New Message";
		my $TITLE = $ZOOVY::cgiv->{'TITLE'};
		my $CATEGORY = $ZOOVY::cgiv->{'CATEGORY'};
		$SM->create($MSGID,$LANG,$LUSERNAME,$TITLE,$CATEGORY);		
	
		$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "<div class='success'>successfully created message $MSGID, go to the appropriate category to edit.</div>";
		
		$VERB = 'NEW-MESSAGE';
		}
	
	
	if ($VERB eq 'NEW-MESSAGE') {
		require SITE::MSGS;	
		my $c = "<option>-</option>";
		foreach my $l (keys %SITE::MSGS::LANGUAGES) {
			$c .= sprintf("<option value=\"%s\">%s</option>",$l,$SITE::MSGS::LANGUAGES{$l}->{'pretty'});
			}
		$GTOOLSUI::TAG{'<!-- LANGUAGES -->'} = $c;
	
		$c = "<option>-</option>";
		foreach my $l (keys %SITE::MSGS::CATEGORIES) {
			$c .= "<option value=\"$l\">$SITE::MSGS::CATEGORIES{$l}</option>";
			}
		$GTOOLSUI::TAG{'<!-- CATEGORIES -->'} = $c;	
	
		$template_file = 'new-message.shtml';
		}
	
	
	if ( ($VERB eq 'CC-MESSAGES') || ($VERB eq 'CHK-MESSAGES') || ($VERB eq 'SYS-MESSAGES') || ($VERB eq 'PAY-MESSAGES') || ($VERB eq 'PAGE-MESSAGES')) {
		require SITE::MSGS;
		my ($SM) = SITE::MSGS->new($USERNAME,RAW=>1,PRT=>$PRT);
	
		$GTOOLSUI::TAG{'<!-- EDITOR -->'} = "<tr><td><i>Please select a message to edit.</i></td></tr>";
		my $EDITID = '';
		my $LANG = '';
	
		if ($ACTION eq 'SAVE') {
			$EDITID = $ZOOVY::cgiv->{'ID'};
			$LANG = $ZOOVY::cgiv->{'LANG'};
	
			my $BLOCKED = 0;
			if (not defined $ZOOVY::cgiv->{'MSG'}) {
				## it's always okay to reset it.
				}
			elsif ($ZOOVY::cgiv->{'MSG'} =~ /\<script/) {
				## javascript warning.
				if ($LU->is_zoovy()) {
					push @MSGS, "WARNING|ZOOVY EMPLOYEE: It is NOT recommended/support placing Javascript into the System Messages, please use Setup | Plugins instead.";
					}
				elsif ($LU->is_bpp()) {
					push @MSGS, "ERROR|BPP settings prohibit Javascript from being placed into System Messages, please Setup | Plugins instead.";
					$BLOCKED++;
					}
				#elsif ($LU->is_level('7')) {
				#	push @MSGS, "WARNING|It is NOT recommended/support placing Javascript into the System Messages, please use Setup | Plugins instead.";
				#	}
				else {
					push @MSGS, "ERROR|Your account type may not place Javascript into System Messages. Please use Setup | Plugins instead."; 
					$BLOCKED++;
					}
				}
			elsif ($ZOOVY::cgiv->{'MSG'} =~ /src\=[\"\']?http\:/) {
				## system messages.
				if ($LU->is_zoovy()) {
					push @MSGS, "WARNING|ZOOVY EMPLOYEE: It is NOT recommended/support placing Javascript into the System Messages, please use Setup | Plugins instead.";
					}
				elsif ($LU->is_bpp()) {
					push @MSGS, "ERROR|BPP settings prohibit insecure (http) references from being placed into System Messages, please Setup | Plugins instead.";
					$BLOCKED++;
					}
				#elsif ($LU->is_level('7')) {
				#	## no warning, 
				#	push @MSGS, "WARNING|Please review your content, it appears you may have an insecure reference in your html that could cause issues.";
				#	}
				else {
					push @MSGS, "ERROR|Your account type may not place Javascript into System Messages. Please use Setup | Plugins instead."; 
					$BLOCKED++;
					}
				}
		
			my ($result) = -1;
			if (not $BLOCKED) {
				$result = $SM->save($EDITID,$ZOOVY::cgiv->{'MSG'},$LANG,$LUSERNAME);
				}
	
			if ($result==-1) {
				push @MSGS, "WARNING|We're sorry, but your save attempt was blocked by account safety/recommended usage guidelines.";
				}
			elsif ($result==0) {
				$LU->log("SETUP.SYSTEMMSG","Reset/Restored System Message $EDITID ($LANG)","SAVE");
				}
			else {
				$LU->log("SETUP.SYSTEMMSG","Updated Message $EDITID ($LANG)","SAVE");
				}
			push @MSGS, "SUCCESS|Successfully Saved $EDITID ($LANG)";
			}
	
		if ($ACTION eq 'EDIT') {
			$EDITID = $ZOOVY::cgiv->{'ID'};
			$LANG = $ZOOVY::cgiv->{'LANG'};
	
			my ($msgref) = $SM->getref($EDITID, $LANG);
			
			my $jsorig = $msgref->{'defaultmsg'};
			$jsorig = &ZOOVY::incode($jsorig);
			$jsorig =~ s/'/\\'/gs;
	
			$GTOOLSUI::TAG{'<!-- EDITOR -->'} = qq~
	<tr>
		<td>Field Name: <b>$msgref->{'pretty'}</b></td>
	</tr>
	~;
	
			if ($msgref->{'hint'} ne '') {
				$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= qq~
	<tr>
		<td><span class="hint">$msgref->{'hint'}</span></td>
	</tr>
	~;
				}
	
			$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= qq~
	<tr>
		<td>
		<textarea rows=3 cols=60 onFocus="this.rows=25;" style="font-size: 8pt;"  name="MSG">~.&ZOOVY::incode($msgref->{'msg'}).qq~</textarea>
	
		<div class="warning">
		Placing tracking iframes or Javascript code into messages is NOT recommended or supported in any way - in fact we're positive doing so will break something you don't intend.
		Tracking code should ONLY be placed in the third party area in Setup / Plugins.
		</div>
	
		</td>
	</tr>
	<tr>
		<td>
		<input type="submit" class="button" value=" Save ">
		<input type="button" class="button" value=" Reset " onClick="
	document.thisFrm.MSG.value='$jsorig'; return(true);
	">
		</td>
	</tr>
	~;
	
	
	if ($msgref->{'cat'} == 50) {
		## CHECKOUT MESSAGE!
		$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= qq~
	<tr>
		<td class="zoovysub1header">Payment Messages Help</td>
	</tr>
	<tr><td>
	<div align="left">
	<div class="hint">
	Remember that these messages may contain HTML, however the HTML will be stripped for text based email.
	</div>
	<table>
		<tr><td class="zoovysub1header" colspan='2'><font class='title'>Variables available for substitution:</font></td></tr>
		~;
	
		foreach my $macroref (@SITE::MSGS::MACROS) {	
			next if ($macroref->[0] != 50);	# payment!
			if ($macroref->[1] eq '') {
				## title
				$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= "<tr><td class='zoovysub1header' colspan=2>$macroref->[2]</td></tr>";
				}
			else {
				## macro
				$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= "<tr><td>$macroref->[1]</td><td>$macroref->[2]</td></tr>";
				}
			}
		
		$GTOOLSUI::TAG{'<!-- EDITOR -->'} .= qq~
	</table>
	</td></tr>
	
	~;
			}
		}
	
	
		$GTOOLSUI::TAG{'<!-- LANG -->'} = $LANG;
		$GTOOLSUI::TAG{'<!-- EDITID -->'} = $EDITID;
	
	
		my $c = '';
		my $r = '';
	
		my ($prtinfo) = &ZWEBSITE::prtinfo($USERNAME,$PRT);
		my @LANGUAGES = split(',',$prtinfo->{'language'});
		$GTOOLSUI::TAG{'<!-- MODE -->'} = $VERB;
	
		my @msgids = ();
		my $SMDREF = $SM->fetch_msgs();
	
		if ($VERB eq 'CHK-MESSAGES') {
	
			my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
			if ((defined $webdbref->{'@CHECKFIELD'}) && (scalar($webdbref->{'@CHECKFIELD'})>0)) {
				## make a copy of the SITE::MSG::DEFAULTS so we don't trash the global one!
				$SMDREF = Storable::dclone(\%SITE::MSGS::DEFAULTS);
				foreach my $ref (@{$webdbref->{'@CHECKFIELD'}}) {
					$ref->{'defaultmsg'} = '';
					$ref->{'created_gmt'} = 0;
					$ref->{'cat'} = 10;
					$ref->{'pretty'} = 'Custom Checkout Field: '.$ref->{'type'};
					$SMDREF->{'~'.$ref->{'id'}} = $ref;
					}
				}
			}
	
		@msgids = reverse sort keys %{$SMDREF};
	
		use Data::Dumper;
		print STDERR Dumper($SMDREF);
	
	
		foreach my $msgid (@msgids) {
			foreach my $lang (@LANGUAGES) {
				my ($msgref) = $SM->getref($msgid,$lang);
	
	
				next if (($VERB eq 'CHK-MESSAGES') && ($msgref->{'cat'}!=10) && ($msgref->{'cat'}>0));
				next if (($VERB eq 'PAY-MESSAGES') && ($msgref->{'cat'}!=50)  && ($msgref->{'cat'}>0));
				next if (($VERB eq 'SYS-MESSAGES') && ($msgref->{'cat'}!=1)  && ($msgref->{'cat'}>0));
				next if (($VERB eq 'PAGE-MESSAGES') && ($msgref->{'cat'}!=11)  && ($msgref->{'cat'}>0));
				next if (($VERB eq 'CC-MESSAGES') && ($msgref->{'cat'}!=20)  && ($msgref->{'cat'}>0));
				
				if (substr($msgid,0,1) eq '~') {
					foreach my $k (keys %{$SMDREF->{$msgid}}) {
						next if (defined $msgref->{$k});
						$msgref->{$k} = $SMDREF->{$msgid}->{$k};
						}
					}
	
				$r = ($r eq 'r0')?'r1':'r0';
	
				if (($EDITID eq $msgid) && ($lang eq $LANG)) { $r = 'rs'; }	## display as currently selected.
				$c .= "<tr class=\"$r\">";
				$c .= "<td valign='top'><a href=\"/biz/vstore/checkout/index.cgi?MODE=$VERB&ACTION=EDIT&LANG=$lang&ID=$msgid\">$msgid</a></td>";
				$c .= "<td valign='top'>".&ZOOVY::incode($msgref->{'pretty'})."</td>";
				$c .= "<td valign='top'>".&ZTOOLKIT::pretty_date($msgref->{'created_gmt'},-1)." : $msgref->{'luser'}</td>";
				$c .= "<td align=center>$lang</td>";
				$c .= "</tr>";
				}
			}
	
	
		$GTOOLSUI::TAG{'<!-- MESSAGES -->'} = $c;
		$template_file = 'messages.shtml';
		}
	
	
	
	if (uc($ACTION) eq 'WEBUI-SAVE') {
	
		}
	
	if (uc($ACTION) eq "GENERAL-SAVE") {
	
		$webdbref->{"cart_quoteshipping"} = $ZOOVY::cgiv->{'cart_quoteshipping'};
		my $customer_management = $ZOOVY::cgiv->{'customer_management'};
		if (!defined($customer_management)) { $customer_management = 'DEFAULT'; }
		$webdbref->{"customer_management"} = $customer_management;
	
		$webdbref->{'checkout'} = $ZOOVY::cgiv->{'checkout'};
	
		if ($FLAGS =~ /WEB/) {	
			$webdbref->{'chkout_phone'} = $ZOOVY::cgiv->{'chkout_phone'};
	
			if ($ZOOVY::cgiv->{'order_num'}+0 != $ZOOVY::cgiv->{'hidden_order_num'}+0) {
				&CART2::reset_order_id($USERNAME,$ZOOVY::cgiv->{'order_num'}+0);
				}
			if ($ZOOVY::cgiv->{'chkout_order_notes'}) { $webdbref->{"chkout_order_notes"} = 1; } 
			else { $webdbref->{"chkout_order_notes"} = 0; }
	
			$webdbref->{'chkout_payradio'} = (defined $ZOOVY::cgiv->{'chkout_payradio'})?1:0;
			$webdbref->{'chkout_shipradio'} = (defined $ZOOVY::cgiv->{'chkout_shipradio'})?1:0;
	
			$webdbref->{"chkout_save_payment_disabled"} = (defined $ZOOVY::cgiv->{'chkout_save_payment_disabled'})?1:0;
			$webdbref->{"chkout_allowphone"} = (defined $ZOOVY::cgiv->{'chkout_allowphone'})?1:0;
			$webdbref->{"chkout_billshipsame"} = (defined $ZOOVY::cgiv->{'chkout_billshipsame'})?1:0;
			$webdbref->{'chkout_roi_display'} = (defined $ZOOVY::cgiv->{'chkout_roi_display'})?1:0;
	
		
			my $customer_privacy = $ZOOVY::cgiv->{'customer_privacy'};
			if (!defined($customer_privacy)) { $customer_privacy = 'NONE'; }
			$webdbref->{"customer_privacy"} = $customer_privacy;
	
	#		if ($ZOOVY::cgiv->{'adult_content'} =~ /on/i) { 
	#			$webdbref->{"adult_content"} = "on";
	#			if ($FLAGS !~ /,ADULT,/) { &ZACCOUNT::create_exception_flags($USERNAME,'ADULT',0,0); }
	#			} 
	#		else {
	#			$webdbref->{"adult_content"} = "off";
	#			if ($FLAGS =~ /,ADULT,/) { &ZACCOUNT::delete_exception_flags(0,$USERNAME,'ADULT'); }
	#			}
	
			}
		else {
			$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = 
			"<div>Some settings on this page require the <a href='/biz/configurator?VERB=VIEW&BUNDLE=WEB'>WEB</a><br> feature bundle to change, because they require functionality which is not currently available to your account.</div>";
			}
	
		push @MSGS, "SUCCESS|Updated Settings";
		$LU->log("SETUP.CHECKOUT","Updated Checkout Settings","SAVE");
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		$VERB = 'GENERAL';
		}
	
	
	# handle general parameters.
	if ($VERB eq 'GENERAL') {
	
		my $chkout = $webdbref->{'checkout'};
		if ($chkout eq '') { $webdbref->{'checkout'} = 'legacy'; }
	
		$GTOOLSUI::TAG{'<!-- CHECKOUT_LEGACY -->'} = ($webdbref->{'checkout'} eq 'legacy')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_ACTIVE -->'} = ($webdbref->{'checkout'} eq 'active')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_PASSIVE -->'} = ($webdbref->{'checkout'} eq 'passive')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_REQUIRED -->'} = ($webdbref->{'checkout'} eq 'required')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_OP6 -->'} = ($webdbref->{'checkout'} eq 'op6')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_OP7 -->'} = ($webdbref->{'checkout'} eq 'op7')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_OP8 -->'} = ($webdbref->{'checkout'} eq 'op8')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_OP9 -->'} = ($webdbref->{'checkout'} eq 'op9')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130111A -->'} = ($webdbref->{'checkout'} eq 'checkout-20130111a')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130111P -->'} = ($webdbref->{'checkout'} eq 'checkout-20130111p')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130111R -->'} = ($webdbref->{'checkout'} eq 'checkout-20130111r')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130131A -->'} = ($webdbref->{'checkout'} eq 'checkout-20130131a')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130131P -->'} = ($webdbref->{'checkout'} eq 'checkout-20130131p')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_20130131R -->'} = ($webdbref->{'checkout'} eq 'checkout-20130131r')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_201314A -->'} = ($webdbref->{'checkout'} eq 'checkout-201314a')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_201314P -->'} = ($webdbref->{'checkout'} eq 'checkout-201314p')?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHECKOUT_201314R -->'} = ($webdbref->{'checkout'} eq 'checkout-201314r')?'checked':'';
	
		my $chkout_phone = $webdbref->{'chkout_phone'};
		if (!defined($chkout_phone)) { $chkout_phone = 'REQUIRED'; }
		$GTOOLSUI::TAG{'<!-- CHKOUT_PHONE_REQUIRED -->'} = '';
		$GTOOLSUI::TAG{'<!-- CHKOUT_PHONE_OPTIONAL -->'} = '';
		$GTOOLSUI::TAG{'<!-- CHKOUT_PHONE_UNREQUESTED -->'} = '';
		$GTOOLSUI::TAG{'<!-- CHKOUT_PHONE_'.$chkout_phone.' -->'} = ' checked ';
		
		$GTOOLSUI::TAG{'<!-- CM_STANDARD -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_NICE -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_STRICT -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_PASSIVE -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_DISABLED -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_PRIVATE -->'} = '';
		$GTOOLSUI::TAG{'<!-- CM_MEMBER -->'} = '';	
		my $customer_management = $webdbref->{"customer_management"};
		if (!defined($customer_management)) { $customer_management = 'STANDARD'; }
		if ($customer_management eq 'DEFAULT') { $customer_management = 'STANDARD'; }
		$GTOOLSUI::TAG{'<!-- CM_'.$customer_management.' -->'} = ' CHECKED ';
	
		$GTOOLSUI::TAG{'<!-- CHKOUT_ORDER_NOTES_CHECKED -->'} = ($webdbref->{"chkout_order_notes"})?'checked':'';
		$GTOOLSUI::TAG{'<!-- CHKOUT_SAVE_PAYMENT_DISABLED_CHECKED -->'} = ($webdbref->{'chkout_save_payment_disabled'})?'checked':'';
	
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_0 -->"} = ''; 
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_1 -->"} = ''; 
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_2 -->"} = ''; 	
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_3 -->"} = ''; 
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_4 -->"} = ''; 
		$GTOOLSUI::TAG{"<!-- CART_QUOTESHIPPING_".int($webdbref->{"cart_quoteshipping"})." -->"} = 'checked'; 
	
		$GTOOLSUI::TAG{"<!-- CHKOUT_BILLSHIPSAME_CHECKED -->"} = ($webdbref->{"chkout_billshipsame"}) ? 'checked':'';
	
		$GTOOLSUI::TAG{'<!-- CHKOUT_ROI_DISPLAY -->'} = ($webdbref->{'chkout_roi_display'})?'checked':'';
	
		my $DOMAIN = $LU->domain();
		if ($LU->is_anycom()) { # different checkout preferences 
			$template_file = 'checkout-anycom.shtml';
			}
		else {
			$template_file = 'checkout-zoovy.shtml';
			$GTOOLSUI::TAG{'<!-- DOMAIN -->'} = $DOMAIN;
			$GTOOLSUI::TAG{'<!-- CHECKOUTLINK -->'} = sprintf("http://www.$DOMAIN/checkout");
			}
		$HELP = '#50305';
		}
	
	
	if ($VERB eq 'CHECKFIELD') {
		$template_file = 'checkfield.shtml';
		}
	
	
	my @TABS = ();
	push @TABS, { selected=>($VERB eq 'GENERAL')?1:0, name=>'Checkout Config', link=>'/biz/vstore/checkout/index.cgi', target=>'_top' };
	push @TABS, { selected=>($VERB eq 'CUSTOMERADMIN')?1:0, name=>'Customer Admin Config', link=>'/biz/vstore/checkout/index.cgi?MODE=CUSTOMERADMIN', target=>'_top' };
	if ($FLAGS =~ /,WEB,/) {
		push @TABS, {  selected=>($VERB eq 'CHK-MESSAGES')?1:0, name=>'Checkout Msgs', link=>'/biz/vstore/checkout/index.cgi?MODE=CHK-MESSAGES', target=>'_top' };
		push @TABS, {  selected=>($VERB eq 'SYS-MESSAGES')?1:0, name=>'System Msgs', link=>'/biz/vstore/checkout/index.cgi?MODE=SYS-MESSAGES', target=>'_top' };
		push @TABS, {  selected=>($VERB eq 'PAY-MESSAGES')?1:0, name=>'Payment Msgs', link=>'/biz/vstore/checkout/index.cgi?MODE=PAY-MESSAGES', target=>'_top' };
		push @TABS, {  selected=>($VERB eq 'PAGE-MESSAGES')?1:0, name=>'Special Page Msgs', link=>'/biz/vstore/checkout/index.cgi?MODE=PAGE-MESSAGES', target=>'_top' };
		# push @TABS, {  selected=>($VERB eq 'CC-MESSAGES')?1:0, name=>'CallCenter Msgs', link=>'/biz/vstore/checkout/index.cgi?MODE=CC-MESSAGES', target=>'_top' };
		push @TABS, {  selected=>($VERB eq 'NEW-MESSAGE')?1:0, name=>'Create Message', link=>'/biz/vstore/checkout/index.cgi?MODE=NEW-MESSAGE', target=>'_top' };
		}
	
	return(
	   'title'=>'Setup : Checkout Properties',
	   'file'=>$template_file,
	   'header'=>'1',
		'jquery'=>'1',
	   'help'=>$HELP,
	   'tabs'=>\@TABS,
		'msgs'=>\@MSGS,
	   'bc'=>[
	      { name=>'Setup',link=>'/biz/vstore/index.cgi','target'=>'_top', },
	      { name=>'Checkout Properties',link=>'/biz/vstore/checkout/index.cgi','target'=>'_top', },
	      ],
	   );

	}



sub builder_themes {
	my ($JSONAPI,$cgiv) = @_;	
	$ZOOVY::cgiv = $cgiv;
	
	require LUSER;
	my ($LU) = $JSONAPI->LU();
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	
	my $NS = $ZOOVY::cgiv->{'NS'};
	$GTOOLSUI::TAG{'<!-- NS -->'} = $NS;
	my $SUBTYPE = $ZOOVY::cgiv->{'SUBTYPE'};
	## SUBTYPE = "" (wrapper)
	## SUBTYPE = "P" (Popup)
	## SUBTYPE = "E" (Email)
	$GTOOLSUI::TAG{'<!-- SUBTYPE -->'} = $SUBTYPE;
	
	my $DOCTYPE = 'WRAPPER';
	if ($SUBTYPE eq 'E') { $DOCTYPE = 'ZEMAIL'; }
	
	my @TABS = ();
	
	my @BC = ();
	push @BC, { name=>"Setup", link=>"/biz/vstore" };
	push @BC, { name=>"Site Builder", link=>"/biz/vstore/builder" };
	push @BC, { name=>"Profile [$NS]" };
	
	if ($SUBTYPE eq 'E') {
		push @BC, { name=>"Email Template Chooser" };
		push @TABS, { name=>'Select', link=>"/biz/vstore/builder/themes/index.cgi?SUBTYPE=E&NS=$NS", selected=>1 };
		push @TABS, { name=>'Edit', link=>"/biz/vstore/builder/emails/index.cgi?VERB=EDIT&NS=$NS", };
		push @TABS, { name=>'Add', link=>"/biz/vstore/builder/emails/index.cgi?VERB=ADD&NS=$NS", };
		}
	else {
		push @BC, { name=>"Theme Chooser" };
		}
	
	## General Help on Themes
	my $help = "#50270";
	
	$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 1;
	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME);
	## my $NSREF = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
	my ($D) = DOMAIN->new($LU->username(),$LU->domainname());
	my $NSREF = $D->as_legacy_nsref();
	
	if ($webdbref->{'branding'}>0) {
		delete($WRAPPER::logos->{'thawte'});
		delete($WRAPPER::logos->{'geotrust'});
		}


	
	my $template_file = '';
	my $VERB = $ZOOVY::cgiv->{'VERB'};
	my @THEMES = ();
	if ((defined $ZOOVY::cgiv->{'category'}) || (defined $ZOOVY::cgiv->{'color'})) { $VERB = 'SEARCH'; }
	
	if ($VERB eq '') {
		$VERB = 'MYTHEMES';
		}
	
	if (1) {
		my $c = '';
		foreach my $cat (sort {$a<=>$b} keys %TOXML::BW_CATEGORIES) {	
			next if ($TOXML::BW_CATEGORIES{$cat} eq '');
			$c .= "<option value=\"$cat\">$TOXML::BW_CATEGORIES{$cat}</option>\n";
			}
		my $CATS = $c;
	
		$c = '';
		foreach my $color (sort {$a<=>$b} keys %TOXML::BW_COLORS) {
			next if ($TOXML::BW_COLORS{$color} eq '');
			$c .= "<option value=\"$color\">$TOXML::BW_COLORS{$color}</option>\n";
			}
	
		my $TXT = 'Theme List';
		if ($SUBTYPE eq 'E') { $TXT = 'Email Themes'; }
		if ($SUBTYPE eq 'P') { $TXT = 'Popup Themes'; }
		if ($SUBTYPE eq 'M') { $TXT = 'Mobile Themes'; }
	
		my $COLORS = $c;
		my $left = qq~
	
	<form name="thisFrm" action="/biz/vstore/builder/themes/index.cgi">
	<input type="hidden" name="NS" value="$NS">
	<input type="hidden" name="SUBTYPE" value="$SUBTYPE">
	<table cellspacing="2" cellpadding="0" width="170" border="0"><tr>
		<td width="1%"><img
	src="//www.zoovy.com/biz/images/tabs/themes/themes.gif" width="30"
	height="30"></td>
		<td width="99%"><h3>$TXT</h3></td>
	</tr>
	<tr>
		<td colspan="2" align="left">
		<table width="100%" cellspacing=4 cellpadding=0>
		<tr>
			<td width="10"><img width="10" height="10" name="img1" id="img1" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=MYTHEMES&SUBTYPE=$SUBTYPE&NS=$NS">My Themes</td>
		</tr>
		<tr>
			<td width="10"><img width="10" height="10" name="img2" id="img2" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=FAVORITES&SUBTYPE=$SUBTYPE&NS=$NS">Community Favorites</a></td>
		</tr>
		<tr>
			<td width="10"><img width="10" height="10" name="img3" id="img3" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=RECENT&SUBTYPE=$SUBTYPE&NS=$NS">Recently Added</a></td>
		</tr>
		<tr>
			<td width="10"><img width="10" height="10" name="img4" id="img4" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=STAFF&SUBTYPE=$SUBTYPE&NS=$NS">Staff Favorites</a></td>
		</tr>
		<tr>
			<td width="10"><img width="10" height="10" name="img5" id="img5" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=RANKED&SUBTYPE=$SUBTYPE&NS=$NS">Best Ranked</a></td>
		</tr>
		<tr>
			<td width="10"><img width="10" height="10" name="img5" id="img5" src="/images/blank.gif"></td>
			<td align="left"><a href="/biz/vstore/builder/themes/index.cgi?VERB=SHOWALL&SUBTYPE=$SUBTYPE&NS=$NS">Show All</a></td>
		</tr>
	~;
	
	$left .= qq~
		</table>
		<br>
		</td>
	</tr>
	~;
	
		if ($SUBTYPE eq 'AB') {
			$left .= qq~<tr><td colspan=2><a href="/biz/vstore/builder/themes/index.cgi?VERB=SAVE-WRAPPER&NS=$NS&wrapper=&SUBTYPE=AB">DISABLE A/B TEST</a><br><br></td></tr>~;
			}
	
		if ($SUBTYPE eq 'E') {
			## hmm.. no sitemap, no sidebar/header
			}
		elsif ($SUBTYPE eq 'P') {
			## hmm.. no sitemap, no sidebar/header
			}
		elsif ($SUBTYPE eq 'M') {
			## hmm.. no sitemap, no sidebar/header
			}
		else {
			$left .= qq~
	<tr>
		<td><img src="//www.zoovy.com/biz/images/tabs/themes/advanced.gif" width="30" height="30"></td>
	
		<td><h3>Customize</h3></td>
	</tr><tr>
		<td colspan="2"><table width="100%" cellspacing=4 cellpadding=0><tr>
			<td width="10"><img width="10" height="10" name="img6" id="img6" src="/images/blank.gif"></td>
		</tr>
	
		</table><br></td>
	</tr><tr>
		<td>
			<img src="//www.zoovy.com/biz/images/tabs/themes/search.gif" width="30" height="30">
		</td>
		
		<td><h3>Find A Theme</h3></td>
	</tr>
		<tr>
		<td colspan="2" align="left"><table><tr>
			<td width="10" rowspan="6"></td>
			<td align="left"><strong>Category:</strong></td>
		</tr><tr>
			<td align="left">
			<select name="category" id="category" class="dropdown">
				<option value=""> - Any - </option>
				$CATS
			</select>
			</td>
		</tr><tr>
			<td><strong>Color:</strong></td>
		</tr><tr>
			<td align="left">
			<select name="color" id="color" class="dropdown">
				<option value="0"> - Any - </option>
				$COLORS 
		 		</select>
		 	</td>
		</tr><tr>
			<td><strong>Features:</strong></td>
	
		</tr><tr>
			<td>
	<input type="checkbox" value="1" name="minicart" id="minicart">&nbsp;Minicart<br>
	<input type="checkbox" value="1" name="sidebar" id="sidebar">&nbsp;Sidebar<br>
	<input type="checkbox" value="1" name="subcats" id="subcats">&nbsp;Subcats<br>
	<input type="checkbox" value="1" name="embed_search" id="embed_search">&nbsp;Embed Search<br>
	<input type="checkbox" value="1" name="embed_subscribe" id="embed_subscribe">&nbsp;Embed
	
	Subscribe<br>
	<input type="checkbox" value="1" name="embed_login" id="embed_login">&nbsp;Embed Login<br>
	<input type="checkbox" value="1" name="imagecats" id="imagecats">&nbsp;Image Navcats<br></td>
	
		</tr>
	<tr>
		<td align="center" colspan="2">
			<input type="button" onClick="thisFrm.submit();" value="Search" class="button">
		</td>
	</tr></table></td>
	</tr>
		~;
		}
	
	$left .= qq~
		</table>
		</form>
		~;
	
		$GTOOLSUI::TAG{'<!-- LEFT -->'} = $left;
		}
	
	
	
	
	
	
	
	
	########################################################################################################
	## 				D E V E L O P E R 	F U N C T I O N S
	########################################################################################################
	
	
	##
	## save the wrapper, and return them to the main screen
	##		HEY: this is used by both "developer" mode and the regular save-wrapper mode.
	##
	if (($VERB eq 'SAVE-ZEMAIL') || ($VERB eq 'SAVE-WRAPPER') || ($VERB eq 'SAVE-POPUP') || ($VERB eq 'SAVE-WRAPPERB') || ($VERB eq 'SAVE-MOBILE')) {
		my $wrapper = defined($ZOOVY::cgiv->{'selected'}) ? $ZOOVY::cgiv->{'selected'} : '';
		if ($wrapper eq '') { $wrapper = $ZOOVY::cgiv->{'wrapper'}; }	
	
		my $TYPE = $ZOOVY::cgiv->{'TYPE'};
		# this is if they choose a default theme from the main menu, we should reset both the category and product
		if ($TYPE eq '') {
			$TYPE = 'SITE';
			}
	
		my $src = '';
		if (substr($wrapper,0,1) eq '~') {
			$wrapper =~ s/\W//gis;
			$wrapper = '~'.$wrapper;
			$src = 'CUSTOM';
			}
		else {
			$wrapper =~ s/\W//gis;
			}
	
		## clear out the old values from the legacy system
		if ($SUBTYPE eq '') {
			$NSREF->{'zoovy:site_wrapper'} = $wrapper;
			$LU->log('SETUP.BUILDER.THEME',"Updated site wrapper for profile $NS",'SAVE');
			}
		elsif ($SUBTYPE eq 'AB') {
			$NSREF->{'zoovy:site_wrapperb'} = $wrapper;
			$LU->log('SETUP.BUILDER.THEME',"Updated site wrapper *B* for profile $NS",'SAVE');
			}
		elsif ($SUBTYPE eq 'P') {
			$NSREF->{'zoovy:popup_wrapper'} = $wrapper;
			$LU->log('SETUP.BUILDER.THEME',"Updated popup wrapper for profile $NS",'SAVE');
			}
		elsif ($SUBTYPE eq 'M') {
			$NSREF->{'zoovy:mobile_wrapper'} = $wrapper;
			$LU->log('SETUP.BUILDER.THEME',"Updated mobile wrapper for profile $NS",'SAVE');
			}
		elsif ($SUBTYPE eq 'E') {
			$LU->log('SETUP.BUILDER.THEME',"Updated email wrapper for profile $NS",'SAVE');
			$NSREF->{'email:docid'} = $wrapper;
			}
	
	   $D->from_legacy_nsref($NSREF);
	   $D->save();
		$GTOOLSUI::TAG{'<!-- MESSAGE -->'} = "<center><font face='helvetica, arial' color='red' size='5'><b>Successfully Saved!</b></font></center><br><br>";;
	
	
		TOXML::UTIL::remember($USERNAME,'WRAPPER',$wrapper,0);
		$VERB = 'MYTHEMES';
		}
	
	
	
	
	
	##########################################################################################################
	##				T H E M E 	C H O O S E R 		F U N C T I O N S
	##########################################################################################################
	
	#mysql> desc THEME_RANKS;
	#+-------------+-------------------------+------+-----+---------+----------------+
	#| Field       | Type                    | Null | Key | Default | Extra          |
	#+-------------+-------------------------+------+-----+---------+----------------+
	#| ID          | int(10) unsigned        |      | PRI | NULL    | auto_increment |
	#| CREATED_GMT | int(11)                 |      |     | 0       |                |
	#| MID         | int(11)                 |      | MUL | 0       |                |
	#| MERCHANT    | varchar(20)             |      |     |         |                |
	#| WRAPPER     | varchar(30)             |      | MUL |         |                |
	#| TYPE        | enum('','DEV','CUSTOM') |      |     |         |                |
	#| SELECTED    | tinyint(4)              |      |     | 0       |                |
	#+-------------+-------------------------+------+-----+---------+----------------+
	#7 rows in set (0.01 sec)
	
	
	
	
	if ($VERB eq 'REMEMBER-WRAPPER') {
		
		my $WRAPPER = $ZOOVY::cgiv->{'wrapper'};
		require TOXML::UTIL;
		&TOXML::UTIL::remember($USERNAME,'WRAPPER',$WRAPPER,1);
	
		$VERB = 'MYTHEMES';
		}
	
	if ($VERB eq 'FORGET-WRAPPER') {
		
		my $WRAPPER = $ZOOVY::cgiv->{'wrapper'};
		require TOXML::UTIL;
		&TOXML::UTIL::forget($USERNAME,'WRAPPER',$WRAPPER);
	
		$VERB = 'MYTHEMES';
		}
	
	
	#mysql> desc THEMES;
	#+-----------------+------------------+------+-----+---------+----------------+
	#| Field           | Type             | Null | Key | Default | Extra          |
	#+-----------------+------------------+------+-----+---------+----------------+
	#| ID              | int(11)          |      | PRI | NULL    | auto_increment |
	#| NAME            | varchar(30)      |      |     |         |                |
	#| CODE            | varchar(15)      |      | UNI |         |                |
	#| RANK_POPULARITY | int(10) unsigned |      |     | 0       |                |
	#| RANK_REMEMBER   | int(10) unsigned |      |     | 0       |                |
	#| CREATED_GMT     | int(11)          |      |     | 0       |                |
	#| BW_CATEGORIES   | int(10) unsigned |      |     | 0       |                |
	#| BW_COLORS       | int(10) unsigned |      |     | 0       |                |
	#| BW_PROPERTIES   | int(10) unsigned |      |     | 0       |                |
	#| IS_POPUP        | tinyint(4)       |      |     | 0       |                |
	#+-----------------+------------------+------+-----+---------+----------------+
	
	my $pstmt = '';
	if ($VERB eq '') { $VERB = 'MYTHEMES'; }
	if ($VERB eq 'MYTHEMES') {
		## Show the themes a user has marked as favorite.
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'My Themes (All Types)';
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 1;
	
		my $result = &TOXML::UTIL::listDocs($USERNAME,$DOCTYPE);
		if (defined $result) {
			foreach my $ref (@{$result}) {
				$ref->{'WRAPPER_CATEGORIES'} = 1;
				push @THEMES, $ref;
				}
			}
	
		if (scalar(@THEMES)==0) {
			$template_file = 'body-welcome.shtml';
			}
		else {
			$template_file = 'body-menu.shtml';
			}
	
		## NOTE: we need pass down MYTHEMES action so we know to add the 'REMOVE' 
		##	$VERB = 'OUTPUT-FAVORITES';
		}
	
	if ($VERB eq 'SEARCH') {
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'Search Results';
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 1;
		
		my $PROPERTIES = 0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'minicart'})?(1<<0):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'sidebar'})?(1<<1):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'subcats'})?(1<<2):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'embed_search'})?(1<<3):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'embed_subscribe'})?(1<<4):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'embed_login'})?(1<<5):0;
		$PROPERTIES += (defined $ZOOVY::cgiv->{'imagecats'})?(1<<6):0;
		## 1<<9 = wiki text
		## 1<<10 = ajax 
	
		my $CATEGORIES = int($ZOOVY::cgiv->{'category'});
		my $COLORS = int($ZOOVY::cgiv->{'color'});
	
		$pstmt = ' FORMAT=\'WRAPPER\' and MID in (0,'.$MID.') ';	
		if ($PROPERTIES>0) { $pstmt .= (($pstmt ne '')?' and ':'')."(PROPERTIES&$PROPERTIES)=$PROPERTIES "; }
		if ($CATEGORIES>0) { $pstmt .= (($pstmt ne '')?' and ':'')."(WRAPPER_CATEGORIES&$CATEGORIES)>0 "; }
		if ($COLORS>0) { $pstmt .= (($pstmt ne '')?' and ':'')."(WRAPPER_COLORS&$COLORS)>0 "; }
	
		if ($pstmt eq '') {
			## they didn't select anything. FUCKERS!
			}
		else {
			$pstmt = "select * from TOXML where CREATED_GMT>0 and $pstmt";
			}
	
		print STDERR $pstmt."\n";
	
		$VERB = 'QUERY';
		}
	
	
	
	if ($VERB eq 'FAVORITES') {
		## Show user favorites (rank remember)
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'Community Favorites (Currently in Use)'; 
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 2;
		#$pstmt = "select * from TOXML where FORMAT='$DOCTYPE' and CREATED_GMT>0 ";
		#if ($SUBTYPE eq 'P') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#if ($SUBTYPE eq 'M') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#$pstmt .= " and MID in (0,$MID) order by RANK_SELECTED desc,CREATED_GMT desc limit 0,25";
		$VERB = 'QUERY';
		}
	
	if ($VERB eq 'RECENT') {
		## RECENTLY ADDED
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'Recently Added'; 
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 3;
		#$pstmt = "select * from TOXML where FORMAT='$DOCTYPE' and CREATED_GMT>0 ";
		#if ($SUBTYPE eq 'P') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#if ($SUBTYPE eq 'M') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#$pstmt .= " and MID in (0,$MID) order by CREATED_GMT desc limit 0,25";
		$VERB = 'QUERY';
		}
	
	if ($VERB eq 'STAFF') {
		## Staff Favorites??
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'Zoovy Favorites'; 
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 4;
		#$pstmt = "select * from TOXML where FORMAT='$DOCTYPE' and CREATED_GMT>0 ";
		#if ($SUBTYPE eq 'P') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#if ($SUBTYPE eq 'M') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#$pstmt .= " and MID in (0,$MID) order by CREATED_GMT desc limit 15,25";
		$VERB = 'QUERY';
		}
	
	if ($VERB eq 'SHOWALL') {
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'All Available'; 
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 4;
		#$pstmt = "select * from TOXML where FORMAT='$DOCTYPE' and CREATED_GMT>0 ";
		#if ($SUBTYPE eq 'P') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#if ($SUBTYPE eq 'M') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#$pstmt .= " and MID in (0,$MID) order by CREATED_GMT desc";
		$VERB = 'QUERY';
		}
	
	if ($VERB eq 'RANKED') {
		## RANK REMEMBER
		$GTOOLSUI::TAG{'<!-- MENU_TITLE -->'} = 'Best Ranked (Most Remembered)'; 
		$GTOOLSUI::TAG{'<!-- MENUPOS -->'} = 5;
		#$pstmt = "select * from TOXML where FORMAT='$DOCTYPE' and CREATED_GMT>0 ";
		#if ($SUBTYPE eq 'P') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#if ($SUBTYPE eq 'M') { $pstmt .= " and SUBTYPE=".$dbh->quote($SUBTYPE); }
		#$pstmt .= " and MID in (0,$MID) order by RANK_REMEMBER desc,CREATED_GMT desc limit 0,25";
		$VERB = 'QUERY';
		}
	
	if ($VERB eq 'QUERY') {
	
		#print STDERR $pstmt."\n";
		#my $sth = $dbh->prepare($pstmt);
		#$sth->execute();
		#while ( my $hashref = $sth->fetchrow_hashref() ) {
		#	push @THEMES, $hashref;
		#	}
		$VERB = 'OUTPUT';
		}
	
	
	if (($VERB eq 'OUTPUT') || ($VERB eq 'OUTPUT-FAVORITES') || ($VERB eq 'MYTHEMES')) {
		##
		## Build a menu!
		##
		my $out = '';
		my $counter = 0;
		foreach my $t (@THEMES) {
			next if (($SUBTYPE eq '') && ($t->{'SUBTYPE'} ne '_') && ($t->{'SUBTYPE'} ne ''));
			next if ($t->{'DOCID'} eq '');
			
			$out .= &format($JSONAPI->LU(),&lookup_theme($USERNAME,$DOCTYPE,$t->{'DOCID'}),$VERB,$counter++,$SUBTYPE,$FLAGS);
			}

		if ($out eq '') { 
			$out = qq~<table><tr><td>Sorry, but no matching themes could be found based on your search parameters.</td></tr></table>~; 
			}
	
		if (($VERB eq 'OUTPUT-FAVORITES') || ($VERB eq 'MYTHEMES')) {
			## display the currently selected theme.
	
			my $wrapper = $NSREF->{'zoovy:site_wrapper'};		
			my $popwrapper = $NSREF->{'zoovy:popup_wrapper'};
			my $emailwrapper = $NSREF->{'email:docid'};
	
			$out = qq~
				<table>
					<tr><td><b>Selected Site Theme:</b><br>
					~.&format($JSONAPI->LU(),&lookup_theme('WRAPPER',$wrapper),'SELECTED',-1,$SUBTYPE,$FLAGS).qq~</td></tr>				
					~.(($popwrapper ne '')?("<tr><td><b>Selected Popup Theme:</b><br>".&format($JSONAPI->LU(),&lookup_theme('WRAPPER',$popwrapper),'SELECTED',-1,$SUBTYPE,$FLAGS)."</td></tr>"):'').qq~
					~.(($emailwrapper ne '')?("<tr><td><b>Selected Email Theme:</b><br>".&format($JSONAPI->LU(),&lookup_theme('EMAIL',$emailwrapper),'SELECTED',-1,$SUBTYPE,$FLAGS)."</td></tr>"):'').qq~
				</table>
				<br><br>
	
				<b>Remembered $DOCTYPE(s):</b><br>
			~.$out;
			}
		
		$GTOOLSUI::TAG{'<!-- THEMELIST -->'} = $out; $out = undef;
		$template_file = 'body-menu.shtml';
		## 
		}
	
	
	
	###
	##
	##
	##
	###
	sub lookup_theme {
		my ($USERNAME,$doctype,$docid) = @_;
		my $t = {};

		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	
		if ($docid eq '') {
			$t->{'TITLE'} = 'Theme Not Set';
			}
		elsif (substr($docid,0,1) eq '~') {
			## Custom Theme
			my ($toxml) = TOXML->new($doctype,$docid,USERNAME=>$USERNAME);
			if (defined $toxml) {
				my ($configel) = $toxml->findElements('CONFIG');	
				## make a copy of the CONFIG element since when $toxml gets deref'd it will call DESTROY and nuke the values
				foreach my $k (keys %{$configel}) {
					$t->{$k} = $configel->{$k};
					}
				}
	
			if ($t->{'TITLE'} eq '') {
				$t->{'TITLE'} = 'Untitled Custom '.$doctype.': '.$docid;
				}
			$t->{'DOCID'} = $docid;
			$t->{'RANK_SELECTED'} = 100;
			$t->{'RANK_REMEMBER'} = 100;
			$t->{'CREATED_GMT'} = time();
			}
		else {
			$t->{'TITLE'} = $docid;
			$t->{'DOCID'} = $docid;
			}
	
		return($t);
		}
	
	
	
	##########################################################################################################
	##				G E N E R A L 		F U N C T I O N S
	##		(wouldn't these be better suited for WRAPPERS.pm)
	##########################################################################################################
	
	
	sub format {
		my ($LU,$tinfo,$VERB,$counter,$SUBTYPE,$FLAGS) = @_;
	
		my ($PRT) = $LU->prt();
		my ($DOMAIN) = $LU->domain();
		
		##
		## tinfo - is a copy of the config element in the $toxml file.. but it also has some other
		##		properties we don't find in the config element.
		##

		my ($USERNAME) = $LU->username();
		my ($MID) = $LU->mid();
	
		my $out = '';
	   my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
		my $thumburl = "//$MEDIAHOST/graphics/wrappers/".$tinfo->{'DOCID'}.'/preview.jpg';
		if ($tinfo->{'FORMAT'} eq 'ZEMAIL') {
			$thumburl = "//$MEDIAHOST/graphics/emails/".$tinfo->{'DOCID'}.'/preview.jpg';
			}
	
		if ((substr($tinfo->{'DOCID'},0,1) eq '~') || ($tinfo->{'MID'} == $MID)) {

			if ($tinfo->{'THUMBNAIL'} eq '') {
				$thumburl = '//www.zoovy.com/biz/images/setup/custom_theme.gif'; 	
				}
			else {
				# require IMGLIB::Lite;
				# $thumburl = &IMGLIB::Lite::url_to_image($USERNAME,$tinfo->{'THUMBNAIL'},140,100,'FFFFFF',0,0);
	         $thumburl = sprintf('//%s%s',
	   			&ZOOVY::resolve_media_host($USERNAME),
	      		&ZOOVY::image_path($USERNAME,$tinfo->{'THUMBNAIL'},W=>140,H=>100,B=>'FFFFFF')
	      		);      
				}
			}
	
	
	#	use Data::Dumper; $out .= "<pre>". Dumper($tinfo). "</pre>";
	
		my $bgcolor = (($counter%2)?'table_top':'table_head');
		if ($counter==-1) { $bgcolor = 'table_head'; }
	
		if ($tinfo->{'TITLE'} eq '') { 
			$tinfo->{'TITLE'} = $tinfo->{'DOCID'}.' Untitled'; 
			}
		
		$out .= "<!-- START: $tinfo->{'DOCID'} -->\n";
		$out .= "<table cellspacing=0 cellpadding=0 border=0 width=\"90%\" class=\"$bgcolor\">\n";
		$out .= "<tr><td>\n";
		$out .= "<table cellspacing=1 cellpadding=0 border=0 width=\"100%\"><tr>";	
	
		$out .= "<td bgcolor=\"#FFFFFF\" valign=\"top\" width=\"1%\">";
		if ($tinfo->{'DOCID'} ne '') {
			$out .= "<img width=140 height=100 src=\"$thumburl\"></td>";
			}
		$out .= "</td>";
		$out .= "<td bgcolor=\"#FFFFFF\" valign=\"top\" width=\"400\" align=\"left\" style=\"padding: 4px;\">";
		$out .= "<strong>$tinfo->{'TITLE'}</strong><br>";
	
		if ($tinfo->{'DOCID'} ne '') {
			$out .= "Document: $tinfo->{'DOCID'}<br>\n";
			}
	
		if ($tinfo->{'CREATED'} ne '') {
			$out .= "Created: $tinfo->{'CREATED'}<br>\n";
			}
	
		if ($tinfo->{'AUTHOR'} ne '') {
			$out .= "Author: $tinfo->{'AUTHOR'}<br>\n";
			}
	
	
		if ($tinfo->{'PROJECT'} ne '') {
			$out .= "Project: $tinfo->{'PROJECT'}<br>\n";
			}
	
		if (($FLAGS =~ /,EBAY,/) && (defined $tinfo->{'BW_PROPERTIES'})) {
			$out .= "Matching Wizard: ".( (($tinfo->{'BW_PROPERTIES'}&(1<<13))>0)?'Yes':'No' )."<br>";
			}
	
		if (substr($tinfo->{'DOCID'},0,1) eq '~') {}
		elsif ($tinfo->{'RANK_REMEMBER'}>0) { 
			$out .= "Popularity: $tinfo->{'RANK_REMEMBER'}<br>\n"; 
			}
	
	
		my $list = '';
		foreach my $i (0..13) { 
			if (($tinfo->{'PROPERTIES'} & (1<<$i))>0) { $list .= ' '.$TOXML::BW_PROPERTIES{1<<$i}.','; } 
			}
		chop($list);
		if ($list eq '') { $list = 'None'; }
	
	
		if ($tinfo->{'OVERLOAD'} ne '') {
			$out .= "OverLoads: ";
			my ($ref) = &ZTOOLKIT::parseparams($tinfo->{'OVERLOAD'});
			foreach my $k (keys %{$ref}) {
				my $pretty = $k;
				if ($k eq 'defaultflow.c') { $pretty = "Default Category Layout ($k)"; }
				elsif ($k eq 'defaultflow.p') { $pretty = "Default Product Layout ($k)"; }
				elsif ($k =~ /flow\.(.*?)$/) { $pretty = "Forced $1 ($k)"; }
				$out .= "<div style='margin-left: 10px;'>&#187; $pretty = $ref->{$k}</div>";
				}
			}
	
		if (substr($tinfo->{'DOCID'},0,1) ne '~') {
			$out .= "Features: $list<br>"; 
			}
	
		if (($VERB eq 'MYTHEMES') || ($VERB eq 'SELECTED')) {
			if ($tinfo->{'SUBTYPE'} eq 'P') {
				$out .= "<font color='red'>*** THIS IS A POPUP WRAPPER ***<br></font>";
				}
			}
	
		$list = '';
		foreach my $i (0..15) {	
			if (($tinfo->{'WRAPPER_CATEGORIES'} & (1<<$i))>0) { $list .= ' '.$TOXML::BW_CATEGORIES{1<<$i}.','; } 		
			}
		chop($list);
		if ($list eq '') { $list = 'None'; }
		if (substr($tinfo->{'DOCID'},0,1) ne '~') {
			$out .= "Categories: $list<br>";
			}
	
		if ($tinfo->{'SITEBUTTONS'} ne '') {
			my $pretty = $tinfo->{'SITEBUTTONS'};
			if (index($tinfo->{'SITEBUTTONS'},'|')<=0) {
				$/ = undef;
				open F, "</httpd/static/graphics/sitebuttons/$tinfo->{'SITEBUTTONS'}/info.txt"; 
				$tinfo->{'SITEBUTTONS'} = <F>; 
				close F;
				$/ = "\n";
				}
			else {
				$pretty = 'Custom Set';
				}
			$out .= "Buttons: $pretty<br>";
			
			$SITE::CONFIG = $tinfo;
			$SITE::CONFIG->{'%SITEBUTTONS'} = &ZTOOLKIT::parseparams($tinfo->{'SITEBUTTONS'});
			my ($SITE) = SITE->new($USERNAME,PRT=>$PRT,'DOMAIN'=>$LU->domainname());
	
			$out .= "<div>";
			foreach my $b ('add_to_cart','cancel','back','forward','|','empty_cart','checkout','continue_shopping','update_cart') {
				if ($b eq '|') { $out .= "<br>"; }
				next if ($b eq '|');
				$out .= "<!-- $b -->";
				$out .= TOXML::RENDER::RENDER_SITEBUTTON({button=>$b},undef,$SITE);
				$out .= " ";
				}
			$out .= "</div>";
			}
		
		# $out .= "<pre>".Dumper($tinfo)."</pre>";
		$out .= "</td></tr></table>";
		$out .= "</td></tr>\n";
	
		if ($tinfo->{'DOCID'} ne '') {
	
			$out .= qq~<tr>
				<td width=99%><table width="100%"><tr>
					<td NOWRAP><span class="light_text">~;
	
			#if ($tinfo->{'FORMAT'} ne 'ZEMAIL') {
			#	$out .= qq~<a target="_preview" href="http:/%3Fwrapper=$tinfo->{'DOCID'}" class="light_text">Preview</a>~;
			#	}
	
			if ($VERB eq 'MYTHEMES') {
				$out .= qq~
				| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=FORGET-WRAPPER&wrapper=$tinfo->{'DOCID'}" class="light_text">Forget</a>
				~;
				}
	
			if ($VERB ne 'SELECTED') {
				## selected is when we are showing a box for a selected theme.
				if ($SUBTYPE eq 'P') {
					$out .= qq~| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=SAVE-POPUP&wrapper=$tinfo->{'DOCID'}" class="light_text"><strong>Select</strong></a>~;
					}
				elsif ($SUBTYPE eq 'M') {
					$out .= qq~| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=SAVE-MOBILE&wrapper=$tinfo->{'DOCID'}" class="light_text"><strong>Select</strong></a>~;
					}
				elsif ($SUBTYPE eq 'E') {
					$out .= qq~| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=SAVE-ZEMAIL&wrapper=$tinfo->{'DOCID'}" class="light_text"><strong>Select Email</strong></a>~;
					}
				else {
					$out .= qq~| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=SAVE-WRAPPER&wrapper=$tinfo->{'DOCID'}" class="light_text"><strong>Select</strong></a>~;
					}
				}
	
			if ($VERB eq 'OUTPUT') {
				## don't offer to remember a them when we are already showing remembered themes.
				$out .= qq~
				| <a href="/biz/vstore/builder/themes/index.cgi?SUBTYPE=$SUBTYPE&DOMAIN=$DOMAIN&VERB=REMEMBER-WRAPPER&wrapper=$tinfo->{'DOCID'}" class="light_text">Remember</a>
				~;
				}
		
	
			$out .= qq~
				</td>
				</tr></table>
	
	</td>
	</tr>
	</table><br>
				~;	
			}
	
		return($out);
		}
	

	return(
		file=>$template_file,
		header=>1,
		bc=>\@BC,
		tabs=>\@TABS,
		help=>$help,
		title=>"Theme Chooser",
		);
	
	}


	sub strip_filename
	{
	   my ($filename) = @_;
	
		my $ext = "";
		my $name = "";
		print STDERR "upload.cgi:strip-filename says filename is: $filename\n";
		my $pos = rindex($filename,'.');
		print STDERR "upload.cgi:strip_filename says pos is: $pos\n";
		if ($pos>0)
			{
			$name = substr($filename,0,$pos);
			$ext = substr($filename,$pos+1);
			
			# lets strip name at the first / or \ e.g. C:\program files\zoovy\foo.gif becomes "foo.gif"
			$name =~ s/.*[\/|\\](.*?)$/$1/;
			# allow periods, alphanum, tildes and dashes to pass through, kill any other special characters
			$name =~ s/[^\w\-\.~]+/_/g;
			# now, remove duplicate periods
			$name =~ s/[\.]+/\./g;
			
			} else {
			# very bad filename!! ?? what should we do!
			}
	
		# we should probably do a bit more sanity on the filename right here
	
		print STDERR "upload.cgi:strip_filename says name=[$name] extension=[$ext]\n";
		return($name,$ext);
	}

##
##
##


sub builder {
	my ($JSONAPI,$cgiv) = @_;

	$ZOOVY::cgiv = $cgiv;
	my ($LU) = $JSONAPI->LU();

	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();

	my @MSGS = ();
	push @MSGS, "WARN|REMINDER: VStore end-of-life is January 1st, 2015.";
	
	my @IMG = ();
	push @IMG, qq~<img src="/biz/loading.gif" width=120 height=60>~;
	$GTOOLSUI::TAG{'<!-- WAIT_IMG -->'} = $IMG[ time()%scalar(@IMG) ];
	
	my $DEBUG = 0;
	my ($LU) = $JSONAPI->LU();
	
	my $DOMAIN = $LU->domain();
	my ($D) = DOMAIN->new($USERNAME,$DOMAIN);
	if ($MID<=0) { exit; }
	$GTOOLSUI::TAG{'<!-- DOMAIN -->'} = $DOMAIN;
	
	my @TABS = ();
	my @BC = ();
	
	
	##
	## generate tabs and breadcrumbs (we must do this after save so $ACTION is set properly)
	##
	push @BC, { name=>'Setup' };
	#if ($LU->is_level('3')) {
	#	push @BC, { name=>'Website Builder', link=>'/biz/vstore/builder/index.cgi', };
	#	}
	
	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my $ACTION = $ZOOVY::cgiv->{'ACTION'};
	print STDERR "ACTION:$ACTION\n";
	
	
	my $template_file = "index.shtml";
	$GTOOLSUI::TAG{"<!-- USERNAME -->"} = $USERNAME;
	$GTOOLSUI::TAG{"<!-- REV -->"} = time();
	
	
	# print STDERR "ACTION: $ACTION\n";
	if ($ACTION eq 'DECALS-SAVE') {
	
		}
	
	##
	##
	##
	if (($ACTION eq 'DECALS') || ($ACTION eq 'DECALS-SAVE')) {
		my ($CHANGES) = 0;
		push @BC, { link=>"/biz/vstore/builder/index.cgi?ACTION=DECALS", name=>"Decals" };
	
		require PRODUCT::FLEXEDIT;
		my ($nsref) = $D->as_legacy_nsref();
	
		my $docid = $nsref->{'zoovy:site_wrapper'};
		my ($tx) = TOXML->new('WRAPPER',$docid,USERNAME=>$USERNAME,MID=>$MID);
		my ($configel) = $tx->findElements('CONFIG');	# fetch the first CONFIG element out of the document.
		$GTOOLSUI::TAG{'<!-- WRAPPER -->'} = $docid;
		
	
		my $thumburl = '';
		if (substr($docid,0,1) ne '~') {
			$thumburl = '/media/graphics/wrappers/'.$docid.'/preview.jpg';
			}
		elsif ($configel->{'THUMBNAIL'} eq '') {
			$thumburl = '/biz/images/setup/custom_theme.gif'; 	
			}
		else {
			$thumburl = sprintf('//%s%s',
				&ZOOVY::resolve_media_host($USERNAME),
				&ZOOVY::image_path($USERNAME,$configel->{'THUMBNAIL'},W=>140,H=>100,B=>'FFFFFF')
				);
			}
		$GTOOLSUI::TAG{'<!-- THUMBURL -->'} = $thumburl;	
	
		my @DECALS = $tx->findElements('DECAL');
		my @SIDEBARS = $tx->findElements('SIDEBAR');
	
		my $c = '';
		my %FLEXEDITS = ();
		foreach my $el (@DECALS,@SIDEBARS) {
			my $IS_SSL = 'N/A';
			my $PREVIEW = '';
	
			my $DATASRC = $el->{'DATA'};
			if (($DATASRC eq '') && ($el->{'TYPE'} eq 'SIDEBAR')) { 
				$DATASRC = 'profile:zoovy:sidebar_logos'; 
				}
	
			if ($el->{'DECALID'}) {
				## this not considered an error, we don't have a DATA when DECALID is specified
				$DATASRC = '';
				}
			elsif ($DATASRC =~ /profile\:(.*?)$/) { 
				$DATASRC = $1; 
				} 
			elsif ($DATASRC =~ /wrapper\:(.*?)$/) { 
				## currently, wrapper:tag is a global alias to merchant:wrapper:tag
				$DATASRC = "wrapper:$1"; 
				} 
			else { 
				## this is probably an error, we need a data (we'll show this error to the user in a bit)
				$DATASRC = ''; 
				}
	
	
			if ($el->{'DECALID'}) {
				## cannot save because decalid is hardcoded
				}
			elsif ($DATASRC eq '') {
				warn "DECAL DATASRC not configured on save for $el->{'ID'}\n";
				}
			elsif ($ACTION eq 'DECALS-SAVE') {
				my @LINES = ();
				my $i = 0;
				while ( defined $ZOOVY::cgiv->{"ELEMENT:$el->{'ID'}.$i"} ) {
					push @LINES, $ZOOVY::cgiv->{"ELEMENT:$el->{'ID'}.$i"};
					$i++;
					}
				$nsref->{$DATASRC} = join("\n",@LINES);
				}
	
			my $pretty = $el->{'PROMPT'};
			if ($pretty eq '') { $pretty = "$el->{'TYPE'}: $el->{'ID'}"; }
	
			## header row
			my $width = $el->{'WIDTH'};
			if ($width eq '') { $width = '?'; }
			my $height = $el->{'HEIGHT'};
			if ($height eq '') { $height = '?'; }
			
			if ($el->{'DECALID'}) {
				## hardcoded decal (specified by designer)
				$c .= "<tr class='zoovysub1header'><td>$pretty (not user configurable, decalid: $el->{'DECALID'})</td></tr>";
				}
			else {
				## user configurable decal
				$c .= "<tr class='zoovysub1header'><td>$pretty ($width by $height)</td></tr>";
				}
	
	
			my $hint = $el->{'HELP'};
			if ($hint eq '') { $hint = $el->{'HELPER'}; }
			if ($hint ne '') { $hint .= "<br>"; }
			if (($el->{'OUTPUTSKIP'} & 256)>0) { $hint .= "<br>** MULTIVARIANT: Will only be shown on 'B' side **"; }
			if (($el->{'OUTPUTSKIP'} & 512)>0) { $hint .= "<br>** MULTIVARIANT: Will only be shown on 'A' side **"; }
	
			if ($el->{'DECALID'}) {
				## forced to a decalid (not configurable)
				}
			elsif ($DATASRC eq '') {
				$hint .= "<br><font color='red'>DATA= could not be determined on element. (this decal is broked).</font>";
				}
			elsif ($nsref->{$DATASRC} eq '') {
				$PREVIEW = "<i>Not selected</i>";
				}
			elsif ( ($nsref->{$DATASRC} ne '') && ($el->{'TYPE'} eq 'DECAL')) {
				## lets verify the DECAL actually exists.
				my $Dref = $TOXML::RENDER::DECALS{ $nsref->{$DATASRC} };
				if (not defined $Dref) {
					$hint .= "<br><font color='red'>Decal $el->{'ID'} references a unknown decal id: $nsref->{$DATASRC}</font>";
					}
				else {
					## we've located the currently selected decal id.
					$IS_SSL = ($Dref->{'ssl'})?'Y':'N';		
					foreach my $flexattr (@{$Dref->{'flexedit'}}) {
						## if $FLEXEDITS{$flexattr} > 1 then it means it's already been shown.		
						if (not defined $FLEXEDITS{ $flexattr }) { $FLEXEDITS{ $flexattr } = 1; }
						}
					}
				}
			## hint row
			$c .= qq~<tr><td valign=top><div class="hint">$hint</div></td></tr>~;
	
			$c .= qq~<tr><td><table>~;
	
	
			## DECAL has 1 slot, SIDEBAR has > 0
			my @SLOTS = ($nsref->{$DATASRC});
			if (($el->{'TYPE'} eq 'DECAL') && ($el->{'DECALID'} ne '')) {
				@SLOTS = ( $el->{'DECALID'} );
				}
			elsif ($el->{'TYPE'} eq 'SIDEBAR') {
				my $i = $el->{'SLOTS'};
				if ($i==0) { $i = 10; }
				@SLOTS = split(/[\|\n]/,$nsref->{$DATASRC}); 
				while (--$i>=0) { 
					if (not defined $SLOTS[$i]) { $SLOTS[$i] = ''; }
					}
				}
	
			# $c .= "<tr><td>".Dumper(\@SLOTS)."</td></tr>";
	
			my ($domain) = &DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT);
			my $pos = 0;
			foreach my $slotvar (@SLOTS) {
				## body row
				## @SLOTS is an array of configured DECALID's
	
				$PREVIEW = '';
				my $options = '';
				foreach my $did (sort keys %TOXML::RENDER::DECALS) {
					my $Dref = $TOXML::RENDER::DECALS{$did};
					## don't display graphics which are too big for the space allocated.
					if ($slotvar eq $did) {
						## if it's selected, we always use / remember it.
						$options .= "<option selected value=\"$did\">$Dref->{'prompt'} (selected)</option>\n";
						$PREVIEW = ($Dref->{'preview'})?$Dref->{'preview'}:$Dref->{'html'};
						if (defined $Dref->{'flexedit'}) {
							foreach my $flexattr (@{$Dref->{'flexedit'}}) {
								if (not defined $FLEXEDITS{ $flexattr }) { $FLEXEDITS{ $flexattr } = 1; }
								}
							#$PREVIEW = "($slotvar==$did) ".Dumper($Dref);
							}
						}
					elsif ((defined $el->{'DECALID'}) && ($did ne $el->{'DECALID'})) {
						$options .= "<!-- $did is not the decal required by the element -->";
						}
					elsif ((defined $Dref->{'height'}) && ($Dref->{'height'}>$el->{'HEIGHT'}) && ($el->{'HEIGHT'}>0)) {
						$options .= "<!-- $did is too tall width=$Dref->{'height'} -->\n";
						}
					elsif ((defined $Dref->{'width'}) && ($Dref->{'width'}>$el->{'WIDTH'}) && ($el->{'WIDTH'}>0)) {
						$options .= "<!-- $did is too wide width=$Dref->{'width'} -->\n";
						}
					else {
						$options .= "<option value=\"$did\">$Dref->{'prompt'}</option>\n";
						}
					}
	
				## cheap hack to get ssl rewrites working.
				$PREVIEW =~ s/%sdomain%/$domain/gos;
			
				$c .= "<tr>";
				$c .= qq~<td valign=top>~;
				$c .= qq~<select name=\"ELEMENT:$el->{'ID'}.$pos\">$options</select>~;
				$c .= qq~<br><!-- slot=[$pos] --> SSL: $IS_SSL~;
				$c .= qq~</td>~;
				# $PREVIEW = &ZOOVY::incode($PREVIEW);
				if ($PREVIEW =~ /\<script/i) {
					$PREVIEW =~ s/\<script.*?\>.*?\<\/script\>//gs;
					$PREVIEW .= "<div class=\"caution hint\">NOTE: JAVASCRIPT NOT AVAILABLE IN PREVIEW</div>";
					}
		
				$c .= qq~<td valign=top>$PREVIEW</td>~;
				$c .= qq~<td valign="top">~;
	
				## okay now we'll show any flexedit fields.
				my @FLEXFIELDS = ();
				foreach my $flexid (sort keys %FLEXEDITS) {
					next if ($FLEXEDITS{$flexid}>1);
					$FLEXEDITS{$flexid} = 2;
					$PRODUCT::FLEXEDIT::fields{$flexid}->{'id'} = $flexid;
					push @FLEXFIELDS, $PRODUCT::FLEXEDIT::fields{$flexid};
					}
				if (scalar(@FLEXFIELDS)>0) {
					if ($ACTION eq 'DECALS-SAVE') {
						PRODUCT::FLEXEDIT::prodsave(undef,\@FLEXFIELDS,$ZOOVY::cgiv,'%dataref'=>$nsref);
						}
					$c .= &PRODUCT::FLEXEDIT::output_html(undef,\@FLEXFIELDS,'USERNAME'=>$USERNAME,'PRT'=>$PRT,'%dataref'=>$nsref);
					}
				# $c .= Dumper(\@FLEXFIELDS);
				$c .= "</td></tr>";
				$pos++;
				}
	
			$c .= "</table>";
			$c .= "</td>";
			$c .= "</tr>";	
			}
	
		# 	print STDERR 'INDEX DUMP'.Dumper($ZOOVY::cgiv->{'user:decal5'});
	
		$GTOOLSUI::TAG{'<!-- POSITIONS -->'} = $c;
	
		## commit saves to disk.
		if ($ACTION eq 'DECALS-SAVE') {
			$D->from_legacy_nsref($nsref);
			$D->save();
			$LU->log('SETUP.BUILDER.DECALS',"Updated decals/sidebar for DOMAIN:$DOMAIN","SAVE");
			}
		
		$template_file = 'decals.shtml';
		}
	
	
	
	if ($ACTION eq 'EDIT-WRAPPER') {
		$ACTION = 'INITEDIT';
		$ZOOVY::cgiv->{'FORMAT'} = 'WRAPPER';
		}
	
	
	
	##
	##
	##
	
	my $SITEstr = undef;
	my $SITE = undef;
	if (defined $ZOOVY::cgiv->{'_SREF'}) {
		$SITE = SITE::sitedeserialize($USERNAME,$ZOOVY::cgiv->{'_SREF'});
		}
	elsif ($ACTION eq 'INITEDIT') {
	
		$SITE = SITE->new($USERNAME,'PRT'=>$PRT,'DOMAIN'=>$DOMAIN);
	
		$SITE->sset('_FORMAT',$ZOOVY::cgiv->{'FORMAT'});
		if ($ZOOVY::cgiv->{'SKU'}) {
			$SITE->setSTID($ZOOVY::cgiv->{'SKU'});
			$SITE->sset('_FORMAT','PRODUCT');
			}
	
		$SITE->sset('_FS',$ZOOVY::cgiv->{'FS'});
	
		if ($ZOOVY::cgiv->{'FL'}) {
			$SITE->layout( $ZOOVY::cgiv->{'FL'} );
			}
		
		$SITE->{'_is_preview'}++;
	
		if ($SITE->format() eq 'WRAPPER') {
			## WRAPPER ?? EMAIL?? editing a specific docid w/o page namespace.
			$SITE->pageid( $ZOOVY::cgiv->{'PG'} );
			if ($SITE->layout() eq '') {
				my $nsref = $SITE->nsref();
				$SITE->layout( $nsref->{'zoovy:site_wrapper'} );
				}
			}
		elsif ($SITE->format() eq 'EMAIL') {
			if ($SITE->layout() eq '') {
				# $SITE->layout( &ZOOVY::fetchmerchantns_attrib($USERNAME,$D->profile(),'email:docid') );
				my ($nsref) = $D->as_legacy_nsref();
				$SITE->layout( $nsref->{'email:docid'} );
				}
			}
		elsif ($SITE->format() eq 'PRODUCT') {
			$SITE->pageid( $SITE->pid() );
			if ($SITE->layout() eq '') {
				my $P = $SITE->pRODUCT();
				if ((ref($P) eq 'PRODUCT') && ($P->fetch('zoovy:fl') ne '')) { 
					$SITE->layout( $P->fetch('zoovy:fl') ); 
					}
				}
			}
		elsif ($SITE->format() eq 'PAGE') {
			$SITE->pageid( $ZOOVY::cgiv->{'PG'} );
			if ($SITE->layout() eq '') {
				my $PG = $SITE->pAGE(); 
				$SITE->layout( $PG->docid() );
				}
		#	print STDERR Dumper($SITE);
			}
		#elsif ($SITE->format() eq 'WIZARD') {
		#	$SITE->pageid( $SITE->pid() );
		#	if ($SITE->layout() eq '') {
		#		my $P = $SITE->pRODUCT()->fetch('zoovy:fl');
		#		if ((ref($P) eq 'PRODUCT') && ($P->fetch('zoovy:fl') ne '')) { 
		#			$SITE->layout( $P->fetch('zoovy:fl') ); 
		#			}
		#		}
		#	}
		elsif ($SITE->format() eq 'NEWSLETTER') {
			my $ID = 0;
			$SITE->pageid( $ZOOVY::cgiv->{'PG'} );
			if ($SITE->layout() eq '') {
				my $PG = $SITE->pAGE(); 
				$SITE->layout( $PG->docid() );
				}		
			# if ($SITE->pageid() =~ /^\@CAMPAIGN:([\d]+)$/) { $ID = $1; }
			#$SITE->layout($ZOOVY::cgiv->{'FL'});
			#my ($P) = PAGE->new($USERNAME,$SITE->pageid());
			#$P->set('FL',$ZOOVY::cgiv->{'FL'});
			#$P->save();
			}
		else {
			push @MSGS, "ERROR|+INVALID FORMAT: ".$SITE->format();
			}
		
		
		if (not defined $SITE) {
			$ACTION = 'ERROR';
			}
		elsif ((not defined $SITE->layout()) || ($SITE->layout() eq '')) {
			$ACTION = 'CHOOSER';
			}
		else { 
			$ACTION = 'EDIT'; 
			}
	
		$SITEstr =  $SITE->siteserialize();
		}
	
	#if (&ZOOVY::is_zoovy_ip()) {
	#	push @MSGS, "DEBUG|ZOOVY STAFF ACTION[$ACTION] DEBUG: ".Dumper($SITE);
	#	}
	#open F, ">/tmp/format";
	#print F Dumper($SITE, $ZOOVY::cgiv);
	#close F;
	
	if ($ACTION eq 'DIVSELECT') {
		$SITE->{'_DIV'} = $ZOOVY::cgiv->{'DIV'};
		$ACTION = 'EDIT';
		$SITEstr =  $SITE->siteserialize();
		}
	
	##
	## Chooser lets us select a new flow.
	##
	if ($ACTION eq "CHOOSERSAVE") {
	
		## NOTE: this should never be reached without $SITE being set.	
		if ($ZOOVY::cgiv->{'FL'}) {
			$SITE->layout($ZOOVY::cgiv->{'FL'});
			}
	
		if ($SITE->format() eq 'WRAPPER') {	
			die("alas, wrappers are not saved/configured by this tool (only edited)");
			}
		elsif ($SITE->format() eq 'EMAIL') {
			$D->set('email.docid',$SITE->docid()); $D->save();
			$LU->log('SETUP.BUILDER.EMAIL',"Saved new layout ".$SITE->docid()." for profile ".$D->profile(),"SAVE");
			}
		elsif ($SITE->format() eq 'PRODUCT') {
			my ($P) = PRODUCT->new($LU,$SITE->pid()); 
			$P->store('zoovy:fl',$SITE->layout()); 
			$P->save();
			$LU->log('SETUP.BUILDER.SKU',"Saved new layout ".$SITE->layout()." for SKU ".$SITE->pid(),"SAVE");
			}
		elsif ($SITE->format() eq 'PAGE') {
			# currently this flag tells me to save the FLOW
			my ($P) = PAGE->new($USERNAME, $SITE->pageid(),DOMAIN=>$D->domainname(),PRT=>$SITE->prt());
			$P->set('FL',$SITE->layout());
			$D->set(lc('our.default_flow'.$SITE->fs()),$SITE->layout()); $D->save();
			$LU->log('SETUP.BUILDER.PAGE',"Saved new layout ".$SITE->layout()." for page ".$SITE->fs()." profile ".$SITE->layout(),"SAVE");
			}
		elsif ($SITE->format() eq 'WIZARD') {
			die("This line should never be reached");
			}
		else {
			die("unsupported toxml->format '".$SITE->format()."' -- never reached!");
			}
	
		$ACTION = 'EDIT';
		$SITEstr =  $SITE->siteserialize();
		}
	
	
	##
	## Meta properties editor.
	##
	if ($ACTION eq 'METASAVE') {
	
		if ($SITE->pid() eq '') {
			my ($P) = PAGE->new($SITE->username(),$SITE->pageid(),DOMAIN=>$D->domainname(),PRT=>$PRT);
			$P->set('page_head',$ZOOVY::cgiv->{'HEAD'});
			$P->set('page_title',$ZOOVY::cgiv->{'PAGE_TITLE'});
			$P->set('head_title',$ZOOVY::cgiv->{'HEAD_TITLE'});
			my $keywords = $ZOOVY::cgiv->{'KEYWORDS'};
			$keywords =~ s/\n/ /gs; # Nuke newlines
			$P->set('meta_keywords',$keywords);
			my $description = $ZOOVY::cgiv->{'DESCRIPTION'};
			$description =~ s/\n/ /gs; # Nuke newlines
			$P->set('meta_description',$description);
			$P->save();
			$LU->log('SETUP.BUILDER.META',"Saved meta properties for ".$SITE->pageid(),"SAVE");
			}
		else {
			my ($P) = PRODUCT->new($LU,$SITE->pid()); 
			$P->store('zoovy:prod_name',$ZOOVY::cgiv->{'TITLE'}); 
			$P->store('zoovy:meta_desc',$ZOOVY::cgiv->{'DESCRIPTION'}); 
			$P->store('zoovy:keywords',$ZOOVY::cgiv->{'KEYWORDS'}); 
			$P->save();
	
			$LU->log('SETUP.BUILDER.META',"Saved meta properties for SKU: ".$SITE->pid(),"SAVE");
			}
		
		$SITEstr =  $SITE->siteserialize();
		$ACTION = 'METAEDIT';
		}
	
	
	if ($ACTION eq 'TOXMLSAVE') {
		$ACTION = 'EDIT';
		require TOXML::COMPILE;
		
		my $content = $ZOOVY::cgiv->{'CONTENT'};
		my ($toxml) = TOXML::COMPILE::fromXML('LAYOUT',$SITE->layout(),$content,USERNAME=>$USERNAME,MID=>$MID);
	
		$LU->log('SETUP.BUILDER.TOXMLSAVE',"Save layout: ".$SITE->layout(),"SAVE");
		if (defined $toxml) {
			$toxml->save();
			$SITE->layout( $toxml->docId() );
			push @MSGS, "SUCCESS|successfully saved ".$SITE->format().":".$SITE->layout();
			}
		else {
			push @MSGS, "ERROR|could not save ".$SITE->format().":".$SITE->layout();
			}
		}
	
	##
	##
	##
	if ($ACTION eq 'COMPANYSAVE') {
	
		require DOMAIN::TOOLS;
	
		my ($ref) = $D->as_legacy_nsref();
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	
		$ref->{'zoovy:site_wrapper'} = $ZOOVY::cgiv->{'SP_WRAPPER'};
		$ref->{'zoovy:site_rootcat'} = $ZOOVY::cgiv->{'SP_ROOTCAT'};
		$ref->{'zoovy:site_schedule'} = $ZOOVY::cgiv->{'SP_SCHEDULE'};
		$ref->{'prt:id'} = $ZOOVY::cgiv->{'SP_PARTITION'};
		
		$ref->{'zoovy:support_phone'} = $ZOOVY::cgiv->{'zoovy:support_phone'};
		$ref->{'zoovy:support_email'} = $ZOOVY::cgiv->{'zoovy:support_email'};
		$ref->{'zoovy:company_name'} = $ZOOVY::cgiv->{'zoovy:company_name'};
		$ref->{'zoovy:seo_title'} = $ZOOVY::cgiv->{'zoovy:seo_title'};
		$ref->{'zoovy:seo_title_append'} = $ZOOVY::cgiv->{'zoovy:seo_title_append'};
		$ref->{'zoovy:firstname'} = $ZOOVY::cgiv->{'zoovy:firstname'};
		$ref->{'zoovy:middlename'} = $ZOOVY::cgiv->{'zoovy:middlename'};
		$ref->{'zoovy:lastname'} = $ZOOVY::cgiv->{'zoovy:lastname'};
		$ref->{'zoovy:address1'} = $ZOOVY::cgiv->{'zoovy:address1'};
		$ref->{'zoovy:address2'} = $ZOOVY::cgiv->{'zoovy:address2'};
		$ref->{'zoovy:city'} = $ZOOVY::cgiv->{'zoovy:city'};
		$ref->{'zoovy:state'} = $ZOOVY::cgiv->{'zoovy:state'};
		$ref->{'zoovy:country'} = $ZOOVY::cgiv->{'zoovy:country'};
		$ref->{'zoovy:zip'} = $ZOOVY::cgiv->{'zoovy:zip'};
		$ref->{'zoovy:phone'} = $ZOOVY::cgiv->{'zoovy:phone'};
		$ref->{'zoovy:facsimile'} = $ZOOVY::cgiv->{'zoovy:facsimile'};
		$ref->{'zoovy:website_url'} = $ZOOVY::cgiv->{'zoovy:website_url'};
	
		foreach my $k (
			'zoovy:support_phone','zoovy:support_email',
			'zoovy:about','zoovy:contact','zoovy:shipping_policy','zoovy:payment_policy',
			'zoovy:return_policy','zoovy:checkout', 'zoovy:business_description') {
			$ref->{$k} = $ZOOVY::cgiv->{$k};
			}
	
		# $ref->{'zoovy:logo_website_pixelmode'} = (defined $ZOOVY::cgiv->{'logo_website_pixelmode'})?1:0;
	
		my $width = $ZOOVY::cgiv->{'width'};
		my $height = $ZOOVY::cgiv->{'height'};
		if ((!defined($width)) || ($width>500) || ($width<1)) { $width = 300; }
		if ((!defined($height)) || ($height>300) || ($height<1)) { $height = 100; }
		$ref->{'zoovy:logo_invoice_xy'} = int($width)."x".int($height);
	
		push @MSGS, "SUCCESS|+Saved settings for DOMAIN:$DOMAIN | prt:$ref->{'prt:id'} root:$ref->{'zoovy:site_rootcat'} wrapper:$ref->{'zoovy:site_wrapper'}";
		$LU->log('SETUP.BUILDER.COMPANY',"Saved settings for DOMAIN:$DOMAIN | prt:$ref->{'prt:id'} root:$ref->{'zoovy:site_rootcat'} wrapper:$ref->{'zoovy:site_wrapper'}","SAVE");
		## &ZOOVY::savemerchantns_ref($USERNAME,$NS,$ref);
		$D->from_legacy_nsref($ref);
		$D->save();
		$ACTION = 'COMPANYEDIT';
	
	
		foreach my $tag (keys %GTOOLSUI::TAG) {
			$GTOOLSUI::TAG{$tag} = &ZTOOLKIT::stripUnicode($GTOOLSUI::TAG{$tag});
			}
		}
	
	
	
	
	print STDERR "ACTION: $ACTION\n";
	$GTOOLSUI::TAG{'<!-- SREF -->'} = $SITEstr;
	
	if ($ACTION eq 'COMPANYEDIT') {
		push @BC, { name=>'Edit Company Info' };
		}
	elsif (not defined $SITE) {
		## the rest of the things require SITE to be populated, it's okay if it's not.
		}
	elsif ($SITE->layout() eq '') {
		## hmm.. not sure what this is. ?? perhaps the TOXML chooser?
		## also the main edit page.
		push @BC, { name=>'Select Template' };
		if (($ACTION eq 'INITEDIT') || ($ACTION eq 'EDIT')) {
			## wow.. they've selected either DOCID or WRAPPER as '' (not undef, but actually blank!)
			push @TABS, { name=>'Layout', link=>'/biz/vstore/builder/index.cgi?ACTION=CHOOSER&_SREF='.$SITEstr, color=>(($ACTION eq 'CHOOSER')?'orange':undef), };
			}
		push @BC, { name=>" format:".$SITE->format()." | pageid:".$SITE->pageid() };
		}
	elsif ($SITE->format() eq 'PRODUCT') {
		my $PID = $SITE->pid();
		$GTOOLSUI::TAG{'<!-- BUTTONS -->'} = qq~
		<center>
			<button class="button2" onClick="navigateTo('/biz/product/edit.cgi?PID=$PID');">Return to Product Editor</button>
		</center>
			~;	
	
		$SITEstr =  $SITE->siteserialize();
		push @TABS, { name=>'Product Editor', 'jsexec'=>"adminApp.ext.admin_prodEdit.a.showPanelsFor('$PID');", };
		push @TABS, { name=>'Layout', link=>'/biz/vstore/builder/index.cgi?ACTION=CHOOSER&_SREF='.$SITEstr, color=>(($ACTION eq 'CHOOSER')?'orange':undef), };
		push @TABS, { name=>'Page Edit', link=>'/biz/vstore/builder/index.cgi?ACTION=EDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'EDIT')?'orange':undef), };
		if (($webdbref->{'pref_template_fmt'} ne '') && (index($FLAGS,',WEB,')>=0) && (substr($SITE->{'_FL'},0,1) eq '~')) {
			push @TABS, { name=>'Edit Template', link=>'/biz/vstore/builder/index.cgi?ACTION=TOXMLEDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'TOXMLEDIT')?'orange':undef), };
			}
		push @BC, { name=>"Edit format:".$SITE->format()." | pageid:".$SITE->pageid()." | layout:".$SITE->layout() };
		}
	elsif ($SITE->format() eq 'NEWSLETTER') {
		$GTOOLSUI::TAG{'<!-- BUTTONS -->'} = qq~
		<center>
			<button class="button2" onClick="navigateTo('/biz/manage/newsletters/index.cgi');">Exit</button>
		</center>
		~;
		push @TABS, { name=>'Page Edit', link=>'/biz/vstore/builder/index.cgi?ACTION=EDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'EDIT')?'orange':undef), };
		push @TABS, { name=>'Layout', link=>'/biz/vstore/builder/index.cgi?ACTION=CHOOSER&_SREF='.$SITEstr, color=>(($ACTION eq 'CHOOSER')?'orange':undef), };
		push @TABS, { name=>'Edit Template', link=>'/biz/vstore/builder/index.cgi?ACTION=TOXMLEDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'TOXMLEDIT')?'orange':undef), };
		push @BC, { name=>"Edit format:".$SITE->format()." pageid:".$SITE->pageid()." layout:".$SITE->layout() };
		$template_file = 'edit-newsletter.shtml';
		}
	elsif ($SITE->format() eq 'PAGE') {
		$GTOOLSUI::TAG{'<!-- BUTTONS -->'} = qq~
		<center>
			<button class="button2" onClick="navigateTo('/biz/vstore/builder/index.cgi');">Exit</button>
		</center>
		~;
		$SITEstr =  $SITE->siteserialize();
		push @TABS, { name=>'Page Edit', link=>'/biz/vstore/builder/index.cgi?ACTION=EDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'EDIT')?'orange':undef), };
		push @TABS, { name=>'Layout', link=>'/biz/vstore/builder/index.cgi?ACTION=CHOOSER&_SREF='.$SITEstr, color=>(($ACTION eq 'CHOOSER')?'orange':undef), };
		if (($webdbref->{'pref_template_fmt'} ne '') && (index($FLAGS,',WEB,')>=0) && (substr($SITE->{'_FL'},0,1) eq '~')) {
			push @TABS, { name=>'Edit Template', link=>'/biz/vstore/builder/index.cgi?ACTION=TOXMLEDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'TOXMLEDIT')?'orange':undef), };
			}
		if (substr($SITE->pageid(),0,1) eq '*') {
			## no live preview for special pages
			}
		else {
			push @TABS, { name=>'Live Preview', link=>'/biz/vstore/builder/index.cgi?ACTION=LIVEPREVIEW&_SREF='.$SITEstr, color=>(($ACTION eq 'LIVEPREVIEW')?'orange':undef), };
			}
		push @TABS, { name=>'Meta Tags', link=>'/biz/vstore/builder/index.cgi?ACTION=METAEDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'METAEDIT')?'orange':undef), };
		push @BC, { name=>"Edit format:".$SITE->format()." pageid:".$SITE->pageid()." layout:".$SITE->layout() };
		}	
	elsif ($SITE->format() eq 'WRAPPER') {
		$GTOOLSUI::TAG{'<!-- BUTTONS -->'} = qq~
		<center>
			<button class="button2" onClick="navigateTo('/biz/vstore/builder/index.cgi');">Exit</button>
		</center>
		~;
		push @TABS, { name=>'Page Edit', link=>'/biz/vstore/builder/index.cgi?ACTION=EDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'EDIT')?'orange':undef), };
		if (($webdbref->{'pref_template_fmt'} ne '') && (index($FLAGS,',WEB,')>=0) && (substr($SITE->{'_FL'},0,1) eq '~')) {
			push @TABS, { name=>'Edit Template', link=>'/biz/vstore/builder/index.cgi?ACTION=TOXMLEDIT&_SREF='.$SITEstr, color=>(($ACTION eq 'TOXMLEDIT')?'orange':undef), };
			}
		push @BC, { name=>"Edit format:".$SITE->format()." pageid:".$SITE->pageid()." layout:".$SITE->layout() };
		}	
	elsif ($SITE->format() ne '') {
		print STDERR Dumper($ZOOVY::cgiv);
		die("Unsupported SITE->format(".$SITE->format().")");
		}
	
	$DEBUG && print STDERR Dumper($SITE);
	
	
	##
	##
	##
	if ($ACTION eq 'LIVEPREVIEW') {
		my $SRC = '';
		$GTOOLSUI::TAG{'<!-- FL -->'} = $SITE->{'_FL'};
		$GTOOLSUI::TAG{'<!-- PG -->'} = $SITE->pageid();
		$GTOOLSUI::TAG{'<!-- SKU -->'} = $SITE->pid();
		$GTOOLSUI::TAG{'<!-- TS -->'} = time();
	
		my $SITE_URL = "http://$USERNAME.zoovy.com";
		if ($LU->prt()>0) {
			$SITE_URL = "http://www.".&DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT);
			}
	
		if ($SITE->pid() ne '') {
			$SRC = "$SITE_URL/product/".$SITE->pid();
			}
		elsif ($SITE->pageid() eq '.') {
			$SRC = "$SITE_URL/";		
			}
		elsif (substr($SITE->pageid(),0,1) eq '.') {
			$SRC = "$SITE_URL/category/".substr($SITE->pageid(),1);		
			}
		elsif (index($SITE->pageid(),'.')==-1) {
			my $v = $SITE->pageid();
			if ($SITE->pageid() eq 'contactus') { $v = 'contact_us'; }
	
			$SRC = "http://$USERNAME.zoovy.com/$v.cgis";
			}
		else {
			$SRC = '#Not Found!';
			}
	
		$GTOOLSUI::TAG{'<!-- SRC -->'} = $SRC;
		$template_file = 'livepreview.shtml';
		}
	
	
	if ($ACTION eq 'SPECIALTYSAVE') {
	
	
		}
	
	
	if ($ACTION eq 'COMPANYEDIT') {
		# handle general parameters.
	
		my $ref = $D->as_legacy_nsref();
		$GTOOLSUI::TAG{"<!-- COMPANY_NAME -->"} = $ref->{'zoovy:company_name'};
		$GTOOLSUI::TAG{"<!-- SEO_TITLE -->"} = $ref->{'zoovy:seo_title'};
		$GTOOLSUI::TAG{"<!-- SEO_TITLE_APPEND -->"} = $ref->{'zoovy:seo_title_append'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_FIRSTNAME -->"} = $ref->{'zoovy:firstname'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_MI -->"} = $ref->{'zoovy:middlename'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_LASTNAME -->"} = $ref->{'zoovy:lastname'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_EMAIL -->"} = $ref->{'zoovy:email'};
		if (not &ZTOOLKIT::validate_email($GTOOLSUI::TAG{'<!-- ZOOVY_EMAIL -->'})) {
			$GTOOLSUI::TAG{'<!-- WARN_EMAIL -->'} = "<font color='red'>warning: if you do not have a contact email, you may miss important messages from zoovy.</font>";
			}
		$ref->{'zoovy:phone'} =~ s/[^\d\-]+//g;	# strip non-numeric digits from phone.
		$GTOOLSUI::TAG{"<!-- ZOOVY_PHONE -->"} = $ref->{'zoovy:phone'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_ADDRESS1 -->"} = $ref->{'zoovy:address1'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_ADDRESS2 -->"} = $ref->{'zoovy:address2'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_CITY -->"} = $ref->{'zoovy:city'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_STATE -->"} = $ref->{'zoovy:state'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_COUNTRY -->"} = substr($ref->{'zoovy:country'},0,2);
		$GTOOLSUI::TAG{"<!-- ZOOVY_ZIP -->"} = $ref->{'zoovy:zip'};
		$GTOOLSUI::TAG{"<!-- ZOOVY_FAX -->"} = $ref->{'zoovy:facsimile'};
		$GTOOLSUI::TAG{'<!-- WEBSITE_URL -->'} = $ref->{'zoovy:website_url'};
	
		foreach my $k ('zoovy:support_phone','zoovy:support_email',
			'zoovy:about','zoovy:contact','zoovy:shipping_policy','zoovy:payment_policy',
			'zoovy:return_policy','zoovy:checkout','zoovy:business_description') {
			$GTOOLSUI::TAG{"<!-- $k -->"} = $ref->{$k};
			}
	
	
		if (
			($GTOOLSUI::TAG{"<!-- zoovy:support_phone -->"} eq '') || 
			($GTOOLSUI::TAG{"<!-- ZOOVY_ZIP -->"} eq '') ||
			($GTOOLSUI::TAG{"<!-- ZOOVY_STATE -->"} eq '') ||
			($GTOOLSUI::TAG{"<!-- ZOOVY_CITY -->"} eq '') ||
			($GTOOLSUI::TAG{"<!-- ZOOVY_ADDRESS1 -->"} eq '') ||
			($GTOOLSUI::TAG{"<!-- zoovy:support_email -->"} eq '')) {
			$GTOOLSUI::TAG{'<!-- BEGIN_WARN -->'} = '<font color="red"><b>';
			$GTOOLSUI::TAG{'<!-- END_WARN -->'} = '</b></font>';
	  		}
	

		if (1) {	
			##
			# $out = "<option value=\"\">Site Theme</option>\n";
			my $THEMES = '';
			if ($ref->{'zoovy:site_wrapper'} ne '') {
				$THEMES = "<option value=\"$ref->{'zoovy:site_wrapper'}\">$ref->{'zoovy:site_wrapper'} (currently selected)</option>\n";
				}
			require TOXML::UTIL;
			foreach my $docref ( @{TOXML::UTIL::listDocs($USERNAME,'WRAPPER',SORT=>1)}) {
				my $wrapper = $docref->{'DOCID'};
				next if ($wrapper eq 'default');
				next unless (($docref->{'REMEMBER'}) || ($docref->{'MID'}>0));
			   $THEMES .= "<option ".(($ref->{'zoovy:site_wrapper'} eq $wrapper)?'selected':'')." value=\"$wrapper\">$wrapper</option>\n";
				}
		
			my $PARTITIONS = '';
			my $globalref = &ZWEBSITE::fetch_globalref($USERNAME);
			my $i = 0;
			foreach my $prt (@{$globalref->{'@partitions'}}) {
				my $selected = ($ref->{'prt:id'} eq $i)?'selected':'';
				$PARTITIONS .= "<option $selected value=\"$i\">[$i] $prt->{'name'}</option>";
				$i++;
				}
	
			my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	
			my $ROOTS = "<option value=\".\">Homepage</option>\n";
			require NAVCAT;
			my ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT);
			my ($pathar) = $NC->fetch_childnodes('.');
			# my ($pathar,$paths) = &NAVCAT::fetch_children($USERNAME,'.');
			# use Data::Dumper; print STDERR Dumper($pathar, $paths);
			my $FOUND_ROOT = 0;
			foreach my $p ('.',@{$pathar}) {
				my ($pretty) = $NC->get($p);
				if ($ref->{'zoovy:site_rootcat'} eq $p) { $FOUND_ROOT++; }
				$ROOTS .= "<option ".(($ref->{'zoovy:site_rootcat'} eq $p)?'selected':'')." value=\"$p\">[$p] $pretty</option>\n";	
				if ((substr($pretty,0,1) eq '!') || ($gref->{'%tuning'}->{'builder_show_all_navcats'})) {
					my ($pathar) = $NC->fetch_childnodes($p);
					# my ($pathar,$paths) = &NAVCAT::fetch_children($USERNAME,$p);
					foreach my $p (@{$pathar}) {
						my ($pretty) = $NC->get($p);
						$ROOTS .= "<option ".(($ref->{'zoovy:site_rootcat'} eq $p)?'selected':'')." value=\"$p\">[$p] $pretty</option>\n";	
						if ($gref->{'%tuning'}->{'builder_show_all_navcats'}>1) {
							# 3rd level for bamtar
							my ($pathar) = $NC->fetch_childnodes($p);
							foreach my $p (@{$pathar}) {
								my ($pretty) = $NC->get($p);
								$ROOTS .= "<option ".(($ref->{'zoovy:site_rootcat'} eq $p)?'selected':'')." value=\"$p\">[$p] $pretty</option>\n";	
								}
							}
						}
					}
				}
			if ($FOUND_ROOT) {
				}
			elsif ($ref->{'zoovy:site_rootcat'} eq '') {
				$ROOTS .= "<option selected value=\"\">-</option>";
				}
			else {
				$ROOTS .= "<option selected value=\"$ref->{'zoovy:site_rootcat'}\">INVALID CATEGORY: $ref->{'zoovy:site_rootcat'}</option>";
				}
	
			my $SCHEDULES = '<option value="">None</option>';
			require WHOLESALE;
			my $SCHEDULE = $ref->{'zoovy:site_schedule'};
			if (($SCHEDULE ne '') && (not WHOLESALE::schedule_exists($USERNAME,$SCHEDULE))) {
				$SCHEDULES .= qq~<option selected value="$SCHEDULE">**INVALID SCHEDULE $SCHEDULE**</option>~;
				}
	
			foreach my $sch (@{&WHOLESALE::list_schedules($USERNAME)}) {
				$SCHEDULES .= "<option ".(($SCHEDULE eq $sch)?'selected':'')." value=\"$sch\">$sch</option>\n";
				#if ($gref->{'%tuning'}->{'allow_default_profile_overrides'}) {
				#	## this user is allowed to change their default behaviors.
				#	}
				#elsif ($NS eq 'DEFAULT') {
				#	$SCHEDULES = '<option value="">Not Available</option>';
				#	$ROOTS= '<option value="">Not Available</option>';
				#	$PARTITIONS = '<option value="0">Not Available</option>';
				#	}
				##
				}
	
			$GTOOLSUI::TAG{'<!-- SITE_CONFIG -->'} = qq~
	<h1>Editing Domain Information: $DOMAIN</h1>
	 
	<table width="100%" class="zoovytable">
		<tr><td colspan=2 class="zoovytableheader">Speciality Site Settings</td></tr>
		<tr><td width=150>Wrapper:</td><td><select name="SP_WRAPPER">$THEMES</select></td></tr>
		<tr><td>Root Category:</td><td><select name="SP_ROOTCAT">$ROOTS</select></td></tr>
		<tr><td>Pricing Schedule:</td><td>
			<select name="SP_SCHEDULE">$SCHEDULES</select></td>
		</tr>
		<tr>
			<td colspan=2>
			<i>NOTE: Site level pricing schedules are not compatible with Apps and/or 1 Page checkout</i>
			</td>
		</tr>
		<tr><td>Data Partition:</td><td><select name="SP_PARTITION">$PARTITIONS</select></td>
		</tr>
		<!-- PARTITION_CONFIG -->
	</table>
		~;
			}
	
		
		my $logo = $ref->{'zoovy:logo_website'};
		$GTOOLSUI::TAG{"<!-- LOGO_WEBSITE -->"} = sprintf('//%s%s',
				&ZOOVY::resolve_media_host($USERNAME),
				&ZOOVY::image_path($USERNAME,$logo,W=>100,H=>100,B=>'FFFFFF')
				);
	#		&IMGLIB::Lite::url_to_image($USERNAME,$logo,100,100,'ffffff');
	#	$GTOOLSUI::TAG{"<!-- LOGO_WEBSITE_PIXELMODE -->"} = ($ref->{'zoovy:logo_website_pixelmode'})?'CHECKED':'';
	
		## NOTE:
		## LOGOYES 
		## http://www.cj.com/, u: tom@zoovy.com, p: SLcsaUK 
	
		my $prt = $ref->{'prt:id'};
		#if ($NS eq 'DEFAULT') { 
		#	$prt = 0; 
		#	}
		#elsif ($prt ne '') {
			## verify we are on the correct profile
		my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$prt);
		#	if ($prtinfo->{'profile'} ne $NS) { $prt = ''; }
		#	}
	
		## types of logo's:
		# zoovy:logo_invoice : logo at the top of an invoice (for this sdomain)
		# zoovy:logo_website : logo that is used for the wrapper
		# zoovy:logo_market  : logo that will be used for marketplaces (no domain name)
		# zoovy:logo_email	: logo for emails
		# zoovy:logo_mobile	: logo for mobile site
	
		# zoovy:company_logo_m
		# zoovy:company_logo
	
		my ($logo_invoice_width,$logo_invoice_height) = split('x',$ref->{'zoovy:logo_invoice_xy'});
		if ((!defined($logo_invoice_width)) || ($logo_invoice_width>500) || ($logo_invoice_width<1)) { $logo_invoice_width = 300; }
		if ((!defined($logo_invoice_height)) || ($logo_invoice_height>500) || ($logo_invoice_height<1)) { $logo_invoice_height = 100; }
		$GTOOLSUI::TAG{'<!-- LOGO_INVOICE_WIDTH -->'} = $logo_invoice_width;
		$GTOOLSUI::TAG{'<!-- LOGO_INVOICE_HEIGHT -->'} = $logo_invoice_height;
	
		my $logo = $ref->{'zoovy:logo_invoice'};
	#	my $logo_invoice_url = &IMGLIB::Lite::url_to_image($USERNAME,$logo,$logo_invoice_width,$logo_invoice_height,'ffffff');
		my $logo_invoice_url = sprintf('//%s%s',
				&ZOOVY::resolve_media_host($USERNAME),
				&ZOOVY::image_path($USERNAME,$logo,W=>$logo_invoice_width,H=>$logo_invoice_height,B=>'FFFFFF')
				);
		$GTOOLSUI::TAG{'<!-- LOGO_INVOICE_URL -->'} = $logo_invoice_url;
		
		$template_file = 'company.shtml';
		}
	
	##
	##
	##
	if ($ACTION eq 'CHOOSER') {
	
		my $title = '';
		my $default = '';
		$template_file = 'chooser.shtml';
		my ($nsref) = $D->as_legacy_nsref();
		if ($SITE->{'_FORMAT'} eq 'EMAIL') {
			$title = "Choose an Email Template";
			# $default = &ZOOVY::fetchmerchantns_attrib($USERNAME,$D->profile(),'zoovy:email_template');
			 $default = $nsref->{'zoovy:email_template'};
			$SITE->sset('_FS','');
			}
		elsif ( index($SITE->pageid(), 'CAMPAIGN') > 0){ 
			my (undef, $CAMPAIGN_ID) = split(/:/, $SITE->pageid());
			$title = "Choose a Newsletter Layout";
			$GTOOLSUI::TAG{"<!-- TITLE -->"} = "Step 2: $title";
			$SITE->sset('_FS','I');
			# $default = &ZOOVY::fetchmerchantns_attrib($USERNAME,$D->profile(),'zoovy:default_flow'.$SITE->fs());
			 $default = $nsref->{ 'zoovy:default_flow'.$SITE->fs() };
			}
		else {
			$title = "Choose a Page Layout";
			push @BC, { name=>"Choose Layout: ".$SITE->pageid(), };
			$GTOOLSUI::TAG{"<!-- TITLE -->"} = $title;
			# $default = &ZOOVY::fetchmerchantns_attrib($USERNAME,$D->profile(),'zoovy:default_flow'.$SITE->fs());
			$default = $nsref->{ 'zoovy:default_flow'.$SITE->fs() };
			}	
	
		print STDERR "SUBTYPE: ".$SITE->fs()."\n";
		my $PROFILE = $ZOOVY::cgiv->{'NS'};
		## $GTOOLSUI::TAG{'<!-- FLOW_CHOOSER -->'} = &TOXML::CHOOSER::buildChooser($SITE->username(),$SITE->format(),SREF=>$SITE->siteserialize(),'NS'=>$PROFILE,SUBTYPE=>$SITE->fs(),selected=>$SITE->layout(),'*LU'=>$LU);


		$GTOOLSUI::TAG{'<!-- FLOW_CHOOSER -->'} = &TOXML::CHOOSER::buildChooser(
			$SITE->username(),
			$SITE->format(),
			SREF=>$SITE->siteserialize(),
			'DOMAIN'=>$DOMAIN,SUBTYPE=>$SITE->fs(),
			selected=>$SITE->layout(),'*LU'=>$LU);
		
		}
	
	
	
	##
	##
	##
	if ($ACTION eq 'METAEDIT') {
		if (ref($SITE) ne 'SITE') {
			push @MSGS, "ISE|Sorry but we could not deference SITE for ACTION METAEDIT";
			}
		elsif ($SITE->pid() eq '') {
			my ($P) = PAGE->new($USERNAME,$SITE->pageid(),DOMAIN=>$D->domainname(),PRT=>$PRT);
			$GTOOLSUI::TAG{'<!-- PAGE_TITLE -->'} = $P->get('page_title');
			$GTOOLSUI::TAG{'<!-- HEAD_TITLE -->'} = $P->get('head_title');
			$GTOOLSUI::TAG{'<!-- HEAD -->'} = $P->get('page_head');
			$GTOOLSUI::TAG{'<!-- DESCRIPTION -->'} = $P->get('meta_description');
			$GTOOLSUI::TAG{'<!-- KEYWORDS -->'} = $P->get('meta_keywords');
			}
		else {
			my ($P) = PRODUCT->new($USERNAME,$SITE->pid());
			$GTOOLSUI::TAG{'<!-- TITLE -->'} = $P->fetch('zoovy:prod_name'); # &ZOOVY::fetchproduct_attrib($USERNAME,$SITE->pid(),'zoovy:prod_name');
			$GTOOLSUI::TAG{'<!-- DESCRIPTION -->'} = $P->fetch('zoovy:meta_desc'); # &ZOOVY::fetchproduct_attrib($USERNAME,$SITE->pid(),'zoovy:meta_desc');
			if ($GTOOLSUI::TAG{'<!-- DESCRIPTION -->'} eq '') {
				$GTOOLSUI::TAG{'<!-- DESCRIPTION -->'} = &ZTOOLKIT::htmlstrip( $P->fetch('zoovy:prod_desc') ); # &ZOOVY::fetchproduct_attrib($USERNAME,$SITE->pid(),'zoovy:prod_desc'));
				}
			$GTOOLSUI::TAG{'<!-- KEYWORDS -->'} = $P->fetch('zoovy:keywords'); # &ZOOVY::fetchproduct_attrib($USERNAME,$SITE->pid(),'zoovy:keywords');
			}
	
		push @BC, { name=>"Page: ".$SITE->pageid(), };
		$template_file = 'meta.shtml';
		$SITEstr = $SITE->siteserialize();
		$GTOOLSUI::TAG{'<!-- SREF -->'} = $SITEstr;
		}
	
	if ($ACTION eq 'EDIT-NEWSLETTER') {  $ACTION = 'EDIT'; }
	
	##
	##
	##
	if ($ACTION eq 'EDIT') {
	
		if (ref($SITE) ne 'SITE') {
			push @MSGS, "ISE|Sorry but we could not deference SITE for ACTION $ACTION";
			}
	
		if ($ZOOVY::cgiv->{'FL'}) { $SITE->layout($ZOOVY::cgiv->{'FL'}); }
	
		$GTOOLSUI::TAG{"<!-- USERNAME -->"} = CGI->escape($USERNAME);
		$GTOOLSUI::TAG{"<!-- FL -->"}       = (defined $SITE->layout())?CGI->escape($SITE->layout()):'';
		$GTOOLSUI::TAG{"<!-- PG -->"}       = (defined $SITE->pageid())?CGI->escape($SITE->pageid()):'';
		$GTOOLSUI::TAG{"<!-- PROD -->"}	    = (defined $SITE->pid())?CGI->escape($SITE->pid()):'';
		$GTOOLSUI::TAG{"<!-- FS -->"}       = (defined $SITE->fs())?CGI->escape($SITE->fs()):'';
		$GTOOLSUI::TAG{"<!-- TS -->"}       = time();
		$GTOOLSUI::TAG{"<!-- REV -->"}      = time();
	
		if (defined $SITE->pageid()) {
			my $NC = NAVCAT->new($USERNAME,PRT=>$PRT); 
			$GTOOLSUI::TAG{'<!-- PRETTYPG -->'} = $NC->pretty_path($SITE->pageid());
			unless ((defined $GTOOLSUI::TAG{'<!-- PRETTYPG -->'}) && ($GTOOLSUI::TAG{'<!-- PRETTYPG -->'} ne '')) {
				$GTOOLSUI::TAG{'<!-- PRETTYPG -->'} = $SITE->pageid();
				}
			}
		elsif (defined $SITE->docid()) {
			$GTOOLSUI::TAG{'<!-- PRETTYPG -->'} = $SITE->{'_FORMAT'}.': '.$SITE->docid();
			}
	
		my $MSG = defined($ZOOVY::cgiv->{'MSG'}) ? $ZOOVY::cgiv->{'MSG'} : '';
		if ($MSG) {
			$GTOOLSUI::TAG{"<!-- MSG -->"} = "<br><center><table border='1' width='80%'><tr><td><b>$MSG</b></td></tr></table></center><br>";
			}
		## added 08/05/2005 - PM
		## decodes html for new (non-edited) custom page layouts
	
		my $FORMAT = $SITE->format();
	
		if ($FORMAT eq 'EMAIL') {
			if ( ($SITE->layout() eq '') && ($ZOOVY::cgiv->{'FL'} ne '') ) {
				$SITE->layout( $ZOOVY::cgiv->{'FL'} );
				}
			push @BC, { name=>sprintf("%s",$SITE->layout()) }
			}
		elsif ($FORMAT eq 'WRAPPER') {
			}
		elsif ($FORMAT eq 'PAGE') {
			}
		elsif ($FORMAT eq 'LAYOUT') {
			}
		elsif ($FORMAT eq 'PRODUCT') {
			}
		elsif ($FORMAT eq 'NEWSLETTER') {
			}
		else {
			push @MSGS, "ERROR|UNKNOWN FORMAT:$FORMAT";
			}
	
		print STDERR "FORMAT: '$FORMAT' LAYOUT: '".$SITE->layout()."'\n";
	
		$GTOOLSUI::TAG{"<!-- BGCOLOR -->"} = '';
		my ($toxml) = TOXML->new($FORMAT,$SITE->layout(),USERNAME=>$USERNAME,MID=>$MID);
	
		my $BUF = '';
		if ($FORMAT eq '') {
			push @MSGS, "ERROR|No FORMAT specified, cannot start edit.";
			}
		elsif ($SITE->layout() eq '') {
			push @MSGS, "ERROR|No DOCID specified (FORMAT:$FORMAT), cannot start edit.";
			}
		elsif (defined $toxml) { 
			$toxml->initConfig($SITE);
			my $TH = $SITE::CONFIG->{'%THEME'};
	
			if (defined($TH->{'content_background_color'})) {
				$GTOOLSUI::TAG{"<!-- BGCOLOR -->"} = $TH->{'content_background_color'};
				}
			my $divsref = $toxml->divs();
			my $GROUP = '';
			if (defined $divsref) {
				unshift @{$divsref}, { TITLE=>'Page Edit', ID=>'' };
				foreach my $divref (@{$divsref}) {
					next if ($divref->{'TITLE'} eq '');
					my $class = ($divref->{'ID'} eq $SITE->{'_DIV'})?'link_selected':'link';
	
					if ($GROUP ne $divref->{'GROUP'}) {
						## output a new group header
						$GROUP = $divref->{'GROUP'};
						$BUF .= qq~<tr><td style="padding: 5px 0px 3px 0px;"><h4>$GROUP</h4></td></tr>~;
						}
	
	
					# $BUF .= qq~<tr><td><input style="text-align: left; width: 120px; margin-bottom: 3px;" 
					#onClick="document.location='index.cgi?ACTION=DIVSELECT&DIV=$divref->{'ID'}&_SREF=$SITEstr';"
					#type="button" class="$class" value="$divref->{'TITLE'}"></td></tr>~;
					$BUF .= qq~<tr><td class="$class"><a href="/biz/vstore/builder/index.cgi?ACTION=DIVSELECT&DIV=$divref->{'ID'}&_SREF=$SITEstr"
	class="$class">$divref->{'TITLE'}</a></td></tr>~;
					#onClick="document.location='';"
					#type="button" class="$class" value="$divref->{'TITLE'}"></td></tr>~;
					}
				}
			$GTOOLSUI::TAG{'<!-- DIVS -->'} = qq~
	<td style="padding-right: 5px;" width="120" valign='top'><table cellspacing=0 cellpadding=0 border=0>
	$BUF
	</table>
	</td>~;
	
			require TOXML::PREVIEW;
			require TOXML::EDIT;
			require SITE;
	
			($BUF) = $toxml->render('*SITE'=>$SITE,DIV=>$SITE->{'_DIV'});
			$BUF =~ s/<[Ss][Cc][Rr][Ii][Pp][Tt].*?><\/[Ss][Cc][Rr][Ii][Pp][Tt]>/<!-- script was removed -->/gs;
			}
		else {
			$BUF = qq~
	The document you are attempting to use DOCTYPE[$FORMAT] DOCID[~.$SITE->layout().qq~] USER[$USERNAME] is not valid or could not be loaded.
	Please select another layout using the Layout tab at the top.
			~;
			}
		
		$GTOOLSUI::TAG{"<!-- CONTENTS -->"} = $BUF;
	
		## set EXIT button and TITLE specific for NEWSLETTERS
		## set back to Newsletter Management page if designing flow for CAMPAIGN
		my $title = "Edit Layout Content";
	
		if( index($SITE->pageid(), 'CAMPAIGN') > 0){
	   	$GTOOLSUI::TAG{"<!-- TITLE -->"} = "Step 3: $title";
		   $GTOOLSUI::TAG{"<!-- FINISH -->"} = "Step 4: Preview";
		   }
		else{
			$GTOOLSUI::TAG{"<!-- TITLE -->"} = $title;
			$GTOOLSUI::TAG{"<!-- FINISH -->"} = "Finish/Save";
	 	  	}
	
		$GTOOLSUI::TAG{'<!-- SREF -->'} = $SITEstr =  $SITE->siteserialize();
		$template_file = 'edit.shtml';
		if ($SITE->format() eq 'NEWSLETTER') {
			$template_file = 'edit-newsletter.shtml';
			}
		}
	
	if ($ACTION eq 'TOXMLEDIT') {
		my $toxml = TOXML->new('LAYOUT',$SITE->{'_FL'},USERNAME=>$USERNAME,MID=>$MID);
		
		if ($webdbref->{'pref_template_fmt'} eq 'XML') {
			$GTOOLSUI::TAG{'<!-- CONTENT -->'} = &ZOOVY::incode($toxml->as_xml());
			}
		elsif ($webdbref->{'pref_template_fmt'} eq 'HTML') {
			$GTOOLSUI::TAG{'<!-- CONTENT -->'} = &ZOOVY::incode($toxml->as_html(0));
			}
		elsif ($webdbref->{'pref_template_fmt'} eq 'PLUGIN') {
			$GTOOLSUI::TAG{'<!-- CONTENT -->'} = &ZOOVY::incode($toxml->as_html(1));
			}
		else {
			$GTOOLSUI::TAG{'<!-- CONTENT -->'} = "Requested template format not supported";
			}
		$GTOOLSUI::TAG{'<!-- _FL -->'} = $SITE->{'_FL'};
	
		## Check for stupid designer errors.
		## 	eventually we ought to display warnings when no wiki tags are available
		##		eventually we ought to check and make sure various subs exit
		##		eventually we ought to check parameters of each layout
		##		eventually we ought to put this in it's own function/module
		##
		my @ERRORS = ();
		my %COUNT = ();
		my %SUBS = ();
		foreach my $el (@{$toxml->getElements()}) {
			if ($el->{'SUB'} eq '') { $SUBS{ $el->{'SUB'} }=0; }
	
			next if ($el->{'TYPE'} eq 'OUTPUT');
			if ($el->{'ID'} eq '') {
				push @ERRORS, "Element $el->{'TYPE'} has no unique ID (how bizarre) - may not render correctly.";
				}
			else {
				$COUNT{ $el->{'ID'} }++;
				}
			}
		foreach my $id (keys %COUNT) {
			if ($COUNT{$id}>1) { 
				push @ERRORS, "ELEMENT ID=$id appears in the document $COUNT{$id} times (should be Unique)"; 
				}
			}
	
		undef %COUNT;
		if (scalar(@ERRORS)) {
			foreach my $msg (@ERRORS) {
				push @MSGS, "ERROR|$msg";
				}
			}
	
		$SITEstr =  $SITE->siteserialize();
		$GTOOLSUI::TAG{'<!-- SREF -->'} = $SITEstr;
		$template_file = 'toxmledit.shtml';
		}
	
	
	
	
	if ($ACTION eq '') {
		require DOMAIN;
		my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$PRT);
	
		my $out = '';
		my %DOMAINS = ();
		my %PROFILES = ();
		my @DEBUG = ();
		my $domain = $LU->domain();
		if ($domain eq '') {
			push @MSGS, "ERROR|domain is unknown";
			}

		$GTOOLSUI::TAG{'<!-- DOMAIN -->'} = uc($domain);
		my $DISPLAY = 0;
		@MSGS = (@MSGS,@DEBUG);
	
		my $class = 'r1';
		$GTOOLSUI::TAG{'<!-- SITE -->'} = &GTOOLSUI::panel_builder($LU,'','LOAD',$D,{});
	
		if (($prtinfo->{'p_navcats'}>0) || ($PRT==0)) {
			## only show navcat's on partition 0, or when the partition has it's own navigation.

			$GTOOLSUI::TAG{'<!-- NAVCATS -->'} = &GTOOLSUI::panel_navcat($LU,'','LOAD',undef,{});
			}
		
		$GTOOLSUI::TAG{'<!-- PROFILES -->'} = $out;	
		}
	
	
	
	
	## detect if we are in popup mode (we're editing a product) 
	##		note: in popup mode we want to skip headers
	my $is_popup = 0;
	if ((defined $SITE) && ($SITE->pid() ne '')) { 
		$is_popup = 1; 
		if (scalar(@MSGS)>0) {
			$GTOOLSUI::TAG{'<!-- MSGS -->'} = &GTOOLSUI::show_msgs(\@MSGS);
			}
		}
	
	return(
		file=>$template_file,
		header=>1,
		'js'=>($ACTION eq 'COMPANYEDIT')?1:0,
		help=>"#50361",
		tabs=>\@TABS,
		msgs=>\@MSGS,
		'jquery'=>'1',
		bc=>\@BC,
		popup=>$is_popup,
		'zmvc'=>1,
		todo=>1,
		);
	
	}
	

sub builder_details {
	my ($JSONAPI,$cgiv) = @_;

	$ZOOVY::cgiv = $cgiv;
	my ($LU) = $JSONAPI->LU();
	
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	
	my $DOCID = $ZOOVY::cgiv->{'DOCID'};
	my $FORMAT = $ZOOVY::cgiv->{'FORMAT'};
	
	require TOXML::CHOOSER;
	my ($t) = TOXML->new($FORMAT,$DOCID,USERNAME=>$USERNAME);
	my $html = TOXML::CHOOSER::showDetails($USERNAME,$t);		
	if (not defined $html) { $html = "<i>Could not load $FORMAT:$DOCID user=$USERNAME</i><br>"; }
	
	return(html=>$html,header=>1);
	}




%GTOOLSUI::TAG = ();
%GTOOLSUI::JSON = ();	## variables to dump into json in the header.


sub panel_navcat {
	my ($LU,$PID,$VERB,$nsref,$formref, %options) = @_;

	if ($VERB eq 'SAVE') {
		return();
		}

	# my $IMAGE_CHOOSER_OKAY = 1;

	my $FLAGS = $LU->flags();
	my $USERNAME = $LU->username();
	my $LUSER = $LU->luser();
	# if ($FLAGS !~ /,WEB,/) { $IMAGE_CHOOSER_OKAY = 0; }

	my $c = '';
	my $flow = '';

	#my $URL = "http://$USERNAME.zoovy.com";
	#if ($LU->prt() > 0) {
	#	}
	my $URL = "http://".&DOMAIN::TOOLS::domain_for_prt($USERNAME,$LU->prt());

	require NAVCAT;
	my $NC = NAVCAT->new($USERNAME,PRT=>$LU->prt());
	my $counter = 0;
	my @paths = sort $NC->paths();

	my $catcount = scalar(@paths);
	my $pagesref = undef;
	if ($catcount>5000) {
		$c = "<tr><td colspan='4'><i>Too many categories ".scalar(@paths)." to display (5000 max)</i></td></tr>";
		@paths = ();
		}
	else {
		require PAGE::BATCH;
		($pagesref) = PAGE::BATCH::fetch_pages($USERNAME,PRT=>$LU->prt(),quick=>1);
		}
		

	foreach my $safe (@paths) {
		$counter++;
		my ($lastedit,$since) = (0,'');
		my $ts = time();
		if ((defined $pagesref) && (defined $pagesref->{$safe})) {
			$lastedit = $pagesref->{$safe}->{'modified_gmt'};
			$since = &ZTOOLKIT::pretty_time_since($lastedit,$ts);
			}
		else {
			## more than 5000 categories doesn't show last edit time. (but is MUCH faster)
			$since = 'N/A';
			$lastedit = -1;
			}

		my $name = $NC->pretty_path($safe);

		# strip the leading period
		my $url = substr($safe,1);

		# at this point $url is setup with the GET safe version (standard decoding like on website)
		my ($PRETTY,$CHILDREN,$PRODUCTS,$SORTSTYLE,$metaref) = $NC->get($safe);
		if (not defined $metaref) { $metaref = {}; }

		if (substr($safe,0,1) eq '*') {
			# hidden page
			}
		elsif (substr($safe,0,1) eq '$') {
			}
		elsif ($safe ne '.') {
			$c .= "<tr><td class='cell'>";
	
			## Image Thumbnail
			my $img = '';
#			if ($IMAGE_CHOOSER_OKAY) {
			$img = $metaref->{'CAT_THUMB'};
#			$c .= "<a href=\"#\" onClick=\"openWindow('/biz/setup/media/popup.cgi?mode=navcat&img=$img&safe=$safe&thumb=img$counter'); return false;\">";
			$c .= "<a href=\"#\" class=\"navcatThumbnailImagePlaceholder\" onClick=\"mediaLibrary(jQuery('#img$counter'),'mode=navcat&img=$img&safe=$safe&thumb=img$counter','Category Thumbnail'); return false;\">";
#				}
#			else {
#				$c .= "<a href=\"#\" onClick=\"openWindow('/biz/vstore/builder/noaccess.shtml');\">";
#				}

			if ((not defined $img) || ($img eq '')) { 
				$c .= qq~<img height="21" width="26" src="data:image/gif;base64,R0lGODlhAQABAIAAAP/MZgAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==" />~;
				} 
			else {
				$img = &ZOOVY::mediahost_imageurl($USERNAME,$img,21,26,'FFFFFF',undef);
				$c .= " <img border=0 id=\"img$counter\" name=\"img$counter\" width=26 height=21 src=\"$img\"></a>";
				}
			## 

			$c .= " $name</td>";
			if ($lastedit == 0) {
				$c .= qq~<td class='cell'><button class="minibutton" onClick="navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&PG=$safe&FS=C'); return false;">Edit</button> &nbsp; ~;
				} 
			else {
				#$flow = $metaref->{'FLOW'};
				#if ($flow eq '') {
				#	## backward compatibility when flows used to be stored in page files.
				#	my $PG = PAGE->new($USERNAME,$safe,NS=>'');
				#	($flow) = $PG->get('FL');
				#	undef $PG;
				#	}
	
				$c .= qq~<td class='cell'><button class="minibutton" onClick="navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&PG=$safe&FS=C'); return false;">Edit</button> &nbsp; ~;
				$c .= "</td>";		
				}
			# $c .= qq~<td class='cell'><button class="minibutton" onClick="linkOffSite('http://www.zoovy.com/biz/preview.cgi?url=$URL/category/$url'); return false;">Preview</button></td>~;
			$c .= "<td class='cell'>$since</td></tr>\n";
			$c .= "<tr><td colspan='4'><div id=\"~$safe\"></div></td></tr>";

			}
		}




	return qq~
<table width=100%>
<tr><td class='cell' colspan='4'><br></td></tr>
<tr>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Product Categories</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Actions</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Preview</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Last Edit</td>
</tr>
<tr>
	<td class='cell' colspan='4'><a href='/biz/setup/navcats/index.cgi?EXIT=/biz/vstore/builder'>Add/Rename/Remove Categories &amp; Lists</a></td>
</tr>
$c
~;

	
	}


##
##
##
sub panel_builder {
	my ($LU,$PID,$VERB,$D,$formref) = @_;

	if ($VERB eq 'SAVE') {
		return();
		}

	my $USERNAME = $LU->username();
	my $LUSERNAME = $LU->luser();
	my $PRT = $LU->prt();
	my $FLAGS = $LU->flags();

	my $PANEL = 'BUILDER:'.$D->domainname();
	my $out = '';

	## my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PROFILE=>$NS,PRT=>$PRT);
	my $WRAPPERS = '';
	## my $ref = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
	my ($nsref) = $D->as_legacy_nsref();

	require ZWEBSITE;
	my $mapped_domain_count = 0;
	my @VSTORE_PREVIEWS = ();

	if ($D) {
		my ($dname) = $D->domainname();
		$mapped_domain_count++;
		foreach my $APPWWWM ('APP','WWW','M') {
			my $HOST_TYPE = $D->{"$APPWWWM\_HOST_TYPE"};
			if ($HOST_TYPE eq '') { $HOST_TYPE = '_NOT_CONFIGURED_'; }
			my %CONFIG = &ZTOOLKIT::parseparams($D->{"$APPWWWM\_CONFIG"});
			if ($HOST_TYPE eq 'APP') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>is APP $CONFIG{'PROJECT'}</td>
				</tr>~;
				}
			elsif ($HOST_TYPE eq 'VSTORE') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>uses legacy website builder (below)</td>
				</tr>~;
				push @VSTORE_PREVIEWS, lc("$APPWWWM.$dname");
				}
			elsif ($HOST_TYPE eq 'REDIR') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>redirects to: http://$CONFIG{'REDIR'}/$CONFIG{'URI'}</td>
				</tr>~;
				}
			else {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>is type $HOST_TYPE</td>
				</tr>~;
				}
			}
		}	


	$out = '';
	my $wrapper = $nsref->{'zoovy:site_wrapper'};
	if ($wrapper eq '') { $wrapper = '&lt; NOT SET &gt;'; }

	my $pop_wrapper = $nsref->{'zoovy:popup_wrapper'};
	if ($pop_wrapper eq '') { $pop_wrapper = 'DEFAULT: '.&ZWEBSITE::fetch_website_attrib($USERNAME,'sitewrapper_n'); }
	if ($pop_wrapper eq '') { $pop_wrapper = 'DEFAULT: Not Set'; }

	my $mobile_wrapper = $nsref->{'zoovy:mobile_wrapper'};
	if ($mobile_wrapper eq '') { $mobile_wrapper = 'm09_moby'; }


	## my $email = &ZOOVY::fetchmerchantns_attrib($USERNAME,$NS,'email:docid');
	my $email = $nsref->{'email:docid'};
	if ($email eq '') { $email = 'Not Set'; }

	##my $prt = &ZOOVY::fetchmerchantns_attrib($USERNAME,$NS,'prt:id');
	##my $prtinfo = '';
	##if ($prt>0) {
	##	$prtinfo = "<tr><td>Partition:</td><td>$prt</td></tr>";
	##	}

	my $DOMAINNAME = $D->domainname();
	$out .= qq~
<table width=100%>
<tr>
	<td>Company Information</td>
	<td><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=COMPANYEDIT&DOMAIN=$DOMAINNAME');">[Edit]</a></td>
</tr>
<tr>
	<td>Email Messages</td>
	<td>
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/emails/index.cgi?VERB=EDIT&DOMAIN=$DOMAINNAME');">[Edit]</a>
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME&SUBTYPE=E');">[Select]</a>
	</td>
	<td>$email</td>
</tr>

<tr>
	<td>WWW Site Theme</td>
	<td>
		~.
		(($wrapper eq '')?'':qq~<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&DOMAIN=$DOMAINNAME&FS=!&FORMAT=WRAPPER&FL=$wrapper');">[Edit]</a>~).
		qq~
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME');">[Select]</a> 
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=DECALS&DOMAIN=$DOMAINNAME');">[Decals]</a>
	</td>
	<td>$wrapper</td>
</tr>
~;


	$out .= qq~
<tr>
	<td>Mobile Site Theme</td>
	<td>
		~.
		(($wrapper eq '')?'':qq~<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&DOMAIN=$DOMAINNAME&FS=!&FORMAT=WRAPPER&FL=$mobile_wrapper');">[Edit]</a>~).
		qq~
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME&SUBTYPE=M');">[Select]</a> 
	</td>
 	<td>$mobile_wrapper</td>
</tr>
</table>
<br>
	~;



	$out .= qq~
<center>
<table width="100%" class="zoovytable">
<tr>
	<td colspan=4 class='zoovytableheader' >Associated Domains</td>
</tr>
<tr>
$WRAPPERS
	~;


#	use Data::Dumper;
#	$out .= Dumper({'DOMAINS'=>\@domains,'PROFILE'=>$NS,'PRT'=>$PRT});

	if ($mapped_domain_count>1) {
		## if we have more than one domain, be sure to mention changes in one wrapper can overwrite another.
		$out .= qq~
<tr>
	<td colspan='4'>
<div class="error">
Two or more domains share the same profile.<br>
Changes in one wrapper will effect the other. In addition having duplicate domains with identical content will cause
duplicate content/SEO issues. This is NOT a recommended or supported configuration. Please reconfigure 
so there is only one associated domain per profile (use as many redirects as necessary).</div><br>
	</td>
</tr>
	~;
		}


## lets download the last modified page times.
my %LASTEDIT = ();
my ($PROFILE) = $D->profile();
my ($pageinfo) = &PAGE::page_info($USERNAME,$PROFILE,[
	'homepage','aboutus','cart','contactus','gallery','login','privacy','results','return','search'
	]);
foreach my $pg (@{$pageinfo}) {
	$LASTEDIT{uc($pg->{'safe'})} = &ZTOOLKIT::pretty_time_since($pg->{'modified'});
	}




$out .= qq~
<tr>
	<td valign=top class='zoovytableheader' align='left' width='200'>Profile Pages</td>
	<td valign=top class='zoovytableheader' align='left'>Actions</td>
	<td valign=top class='zoovytableheader' align='left'>Preview</td>
	<td valign=top class='zoovytableheader' align='left'>Last Edit</td>
</tr>
<tr>
	<td valign=top class='cell' >Homepage</td>
	<td valign=top class='cell' >
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=.&FS=H');">[Edit]</a>
		&nbsp;
	<a href="#" onClick="adminApp.ext.admin.a.showFinderInModal('NAVCAT','.'); return false;">[Products]</a>
	</td>
	<td valign=top class='cell' >
	~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'HOMEPAGE'}</td>
</tr>
<tr>
	<td valign=top class='cell' >About Us</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=aboutus&FS=A');">[Edit]</a></td> 
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/company_info.cgis');">[$preview_domain]<br></a>~;
		}

$out .= qq~
	</td>
	<Td>$LASTEDIT{'ABOUTUS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Contact Us</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=contactus&FS=U');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/contact_us.cgis');">[$preview_domain]<br></a>~;
		}


$out .= qq~
	</td>
	<td valign=top>$LASTEDIT{'CONTACTUS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Privacy Policy</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=privacy&FS=Y');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/privacy.cgis');">[$preview_domain]<br></a>~;
		}


$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'PRIVACY'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Return Policy</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=return&FS=R');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/returns.cgis');">[$preview_domain]<br></a>~;
		}



$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'RETURN'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Shopping Cart Page</td>
	<td valign=top class='cell' >
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=%2Acart&FS=T');">[Edit]</a>
		&nbsp;
	<!--
	<a onClick="adminApp.ext.admin.a.showFinderInModal('NAVCAT','\$shoppingcart'); return false;" href="#">[Products]</a>
	-->
	</td>
	<td valign=top class='cell' >
		~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/cart.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'CART'}</td>
</tr>
~;


#if ($LU->is_level(4)) {
if (1) {
	$out .= qq~
<tr><td valign=top colspan='4'><div id="\~*cart"></div></td></tr>
<tr>
	<td valign=top class='zoovytableheader' align='left' width='200'>Optional Pages</td>
	<td valign=top class='zoovytableheader' align='left'>Actions</td>
	<td valign=top class='zoovytableheader' align='left'>Preview</td>
	<td valign=top class='zoovytableheader' align='left'>Last Edit</td>
</tr>
<tr>
	<td valign=top class='cell' >Search Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=search&FS=S');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/search.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'SEARCH'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Search Results Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=results&FS=E');">[Edit]</a></td>
	<td valign=top class='cell' >&nbsp;</td>
	<td valign=top class='cell' >$LASTEDIT{'RESULTS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Customer Login Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=login&FS=L');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/login.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'LOGIN'}</td>
</tr>
~;
	}

	$out .= "</table>";

	return($out);
	}



##
##
sub show_msgs {
	my ($msgs) = @_;
	my $output = '';

	foreach my $msg (@{$msgs}) {
		my ($type,$msg) = split(/\|/,$msg,2);

		$type = uc($type);
		my $hint = '';
		if ($msg =~ /\n\n/s) { ($msg,$hint) = split(/\n\n/,$msg); }

		$msg = &ZOOVY::incode($msg);
		if ($hint ne '') { 
			$msg = "<div align=\"left\">$msg<div align=\"left\" class=\"hint\">".&ZOOVY::incode($hint)."</div></div>"; }
		if (($type eq 'SUCCESS') || ($type eq 'WIN') || ($type eq 'INFO')) { 
			$msg = "<div  style='width: 800px; align: center' class='success'>$msg</div>"; }
		elsif (($type eq 'WARN') || ($type eq 'WARNING') || ($type eq 'CAUTION')) { 
			$msg = "<div  style='width: 800px; align: center' class='warning'>$msg</div>"; }
		elsif (($type eq 'ERROR') || ($type eq 'ERR')) { 
			$msg = "<div  style='width: 800px; align: center' class='error'>$msg</div>"; }
		elsif ($type eq 'TODO') { $msg = "<div  style='width: 800px; align: center' class='todo'>$msg</div>"; }
		elsif ($type eq 'LEGACY') { $msg = "<div  style='width: 800px; align: center' class='warning legacy'>$msg</div>"; }
		elsif ($type eq 'ISE') { $msg = "<div  style='width: 800px; align: center' class='error ise'>$msg</div>"; }
		elsif ($type eq 'LINK') { 
			## LINK|/path/to/url|text
			my ($href,$txt) = split(/\|/,$msg,2);
			if ($txt eq '') { $hint = "Link $msg"; }
			$msg = "<div  style='width: 800px; align: center' class='todo'><a target=\"_blank\" href=\"$href\">$txt</a></div>"; 
			}
		else {
			$msg = "<div  style='width: 800px; align: center' class=\"unknown_class_$type\">$msg</div>";
			}
		$output .= $msg;
		}
	return($output);
	}

##
## Displays an error message
##
sub errmsg {
	my ($MSG) = @_;
	my $c = "<font color='red'>$MSG</font><br>";	
	return($c);
	}

##
## 
##
sub std_box {
	my ($title,$body,$opts) = @_;
	my $c = qq~<table class='zoovytable'><tr><td class='zoovytableheader'>$title</td></tr><tr class='r0'><td class='cell'>$body</td></tr></table>~;
	return($c);
	}




##
## this is usually called by a VERB=WEBDOC
##
sub gimmewebdoc {
	my ($LU,$docid) = @_;
	my $out = '';

#	if (not defined $LU) {
#		}
#	elsif ($LU->is_zoovy()) {
#		$out .= "<center><table width=800><tr><td><i>Welcome Zoovy staff</i> <a target=\"webdoc\" href=\"https://admin.zoovy.com/webdoc/index.cgi?VERB=EDIT&docid=$docid\">[EDIT]</a></td></tr></table></center>";
#		}
#
#	my ($w) = WEBDOC->new($docid,public=>1);
#	$out .= $w->wiki2html();
#
#	if ($out eq '') {
#		$out = "<i>No content for docid:$docid</i>";
#		}
	$out = "<b>not available</b>";

	$GTOOLSUI::TAG{'<!-- BODY -->'} = $out;
	return('_/webdoc.shtml');
	}

##
## NAME: is the name of the select box
## SELECTED: which value is currently selected (if any)
## LABELSREF: hashref of <option value="value">key</option>
## VALUESREF: the order to sort/display the keys. (
##
#sub select {
#   my ($name,$selected,$labelsref,$valuesref) = @_;
#
#   my $c = '';
#   if (not defined $valuesref) {
#		my @ar = ();
#      @ar = sort keys %{$labelsref};
#		$valuesref = \@ar;
#      }
#
#   my $tmp = undef;
#    foreach my $key (@{$valuesref}) {
#      next if (not defined $key);
#      $tmp = $labelsref->{$key};
#      $c .= "<option ".(($selected eq $tmp)?'selected':'')." value=\"$tmp\">$key</option>";
#    }
#
#   $c = "[<select name=\"$name\">$c</select>]";
#	return($c);
#   }


sub init {
	%GTOOLSUI::TAG = ();
	%GTOOLSUI::JSON = ();
	}



###########################################################################
## imageurl
## handles imagelib/legacy conversion 
## parameters: USERNAME, variable, height, width, background, ssl
## 
sub imageurl {
   my ($USERNAME, $var, $h, $w, $bg, $ssl, $ext, $v) = @_;

	if (not defined $v) { $v = 0; }

	# print STDERR "GT::imageurl received [".((defined $var)?$var:'undef')."]\n";
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	$v += int($gref->{'%tuning'}->{'images_v'});
	# use Data::Dumper; print Dumper($gref);

	# if we don't have an image, pass that along.
	if (!defined($var)) { return undef; }	
	if ($var eq '' || $var eq ' ') { return undef; } 
	if (substr($var,0,1) eq '/') { $var = substr($var,1); }	# remove leading /
	if (substr($var,-1) eq '_') { $var = substr($var,0,-1); } # remove trailing _

#	# check for legacy
#	if (substr($var,0,7) eq 'jedi://') {
#		if ($var =~ /^jedi\:\/\/\~([a-z0-9]+)\/(.*?)$/) {
#			$USERNAME = $1;
#			$var = $2;
#			}
#		}

	my $proto = '';
	if (not defined $ssl) { }		## NOTE: this is probably the best case
	elsif (not $ssl) { $proto = 'http:'; }
	else { $proto = 'https:'; }

	if ($var !~ /^[Hh][Tt][Tt][Pp]/o) {
		# is from imagelibrary
		if (!defined($bg)) { $bg = "FFFFFF"; }
		$bg = lc($bg);	# MEDIA.pm formats these as lowercase (this way we don't have to symlink)

		my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
		if ( (int($h)==0) && (int($w)==0) ) {
			my $dash = '-';
			if ($v>0) { $dash = sprintf("v%d",$v); }
			$var = "$proto//$MEDIAHOST/media/img/$USERNAME/$dash/$var";
			} 
		else {
			$var = "$proto//$MEDIAHOST/media/img/$USERNAME/W$w-H$h-B$bg".(($v)?"-v$v":"")."/$var";
			}

		## added check to see if extension was already on var, patti 2005-10-06
		if ( (defined $ext) && ($ext ne '') && ($var !~ /\.[a-zA-Z][a-zA-Z][a-zA-Z]$/)) {
			$var .= '.'.$ext;
			}
		}


	return($var);
}


sub link_fixup {
	my ($link) = @_;

	if (substr($link,0,1) eq '#') {
		}
	elsif (substr($link,0,1) eq '/') {
		}
	elsif ($link =~ /^[Hh][Tt][Tt][Pp][Ss]?\:/) {
		warn "GTOOLS TAB/BC GOT LINK: $link\n";
		}
	else {
		# convert index.cgi to /path/to/index.cgi
		if (not defined $ENV{'SCRIPT_NAME'}) { 	warn "GTOOLSUI::link_fixup **REQUIRES** $ENV{'SCRIPT_NAME'}\n"; }
		my $path = substr($ENV{'SCRIPT_NAME'},0,rindex($ENV{'SCRIPT_NAME'},'/'));
		$link = "$path/$link"; 
		}

	if (substr($link,0,1) ne '#') {
		($link,my $params) = split(/\?/,$link,2);
		if ($link !~ /\.(pl|cgi)$/) {
			$link = "$link/index.cgi";
			}

		if ((defined $params) && ($params ne '')) {
			$link = "$link?$params";
			}
		}

	return($link);
	}



##
## NOTE: this is a replacement for "print_form" but for now it simply calls print_form till we can deprecate
##	print form
##
## parameters:
##		header (bitwise) 1=output, 2=disable compression
##		file=>filename (the .shtml file)
##		html=>assumes filename has already been read in (ignores file parameter)
##
sub output {
	my (%m) = @_;

	}



1;


__DATA__
	
	./advwebsite/index.cgi
	./builder/details.cgi
	./builder/index.cgi
	./builder/themes/index.cgi
	./billing/index.cgi
	./analytics/index.cgi
	./search/index.cgi
	#!/usr/bin/perl

	
	#!/usr/bin/perl
	
	use lib "/backend/lib";
	use strict;
	require ZOOVY;
	require ZWEBSITE;
	require LUSER;
	require SITE;
	require SITE::EMAILS;
	
	#use URI::Escape;
	use Data::Dumper;
	
	my ($LU) = $JSONAPI->LU();
	my ($MID,$USERNAME,$LUSERNAME,$FLAGS,$PRT) = $LU->authinfo();
	if ($MID<=0) { warn "No auth"; exit; }
	
	my ($VERB) = $ZOOVY::cgiv->{'VERB'};
	if ($VERB eq '') { $VERB = 'EDIT'; }
	print STDERR "VERB: $VERB\n";
	
	my ($NS) = $ZOOVY::cgiv->{'NS'};
	$GTOOLSUI::TAG{'<!-- NS -->'} = $NS;
	my @TABS = ();
	my @MSGS = ();
	
	my $template_file = '';
	
	my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT,'DOMAIN'=>$LU->domainname());
	my ($SE) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE,RAW=>1);
	
	
	if ($VERB eq 'CONFIG') {
		}
	
	
	if ($VERB eq 'MSGNUKE') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		$SE->save($MSGID,"NUKE"=>1);
		push @MSGS, "SUCCESS|+Deleted message $MSGID";
		$VERB = '';
		}
	
	##
	##
	##
	if ($VERB eq 'MSGTEST') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		my ($err) = $SE->send($MSGID,TEST=>1,TO=>$ZOOVY::cgiv->{'MSGFROM'});
		$VERB = 'MSGEDIT';
	
		if ($err) {
			my $errmsg = $SITE::EMAILS::ERRORS{$err};
			push @MSGS, "ERROR|+$errmsg";
			}
		else {
			push @MSGS, "SUCCESS|+Successfully sent test email.";
			}
		}
	
	##
	##
	##
	if ($VERB eq 'MSGSAVE') {
		## 
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
	
		my %options = ();
		$options{'SUBJECT'} = $ZOOVY::cgiv->{'MSGSUBJECT'};
		$options{'BODY'} = $ZOOVY::cgiv->{'MSGBODY'};
		if (defined $ZOOVY::cgiv->{'MSGTYPE'}) {
			$options{'TYPE'} = $ZOOVY::cgiv->{'MSGTYPE'};
			}
		if (defined $ZOOVY::cgiv->{'MSGBCC'}) {
			$options{'BCC'} = $ZOOVY::cgiv->{'MSGBCC'};
			}
		if (defined $ZOOVY::cgiv->{'MSGFROM'}) {
			$options{'FROM'} = $ZOOVY::cgiv->{'MSGFROM'};
			}
	
		$options{'FORMAT'} = 'HTML';
		if (defined $ZOOVY::cgiv->{'MSGFORMAT'}) {
			$options{'FORMAT'} = $ZOOVY::cgiv->{'MSGFORMAT'};
			}
		
		push @MSGS, "SUCCESS|Successfully saved.";
		
		$SE->save($MSGID, %options);
		$VERB = 'MSGEDIT';
		}
	
	##
	##
	##
	if ($VERB eq 'MSGEDIT') {
		my $MSGID = $ZOOVY::cgiv->{'MSGID'};
		my $msgref = $SE->getref($MSGID);
		
		$GTOOLSUI::TAG{'<!-- MSGTYPE -->'} = $msgref->{'MSGTYPE'};
		$GTOOLSUI::TAG{'<!-- MSGID -->'} = uc($MSGID);
		$GTOOLSUI::TAG{'<!-- MSGSUBJECT -->'} = &ZOOVY::incode($msgref->{'MSGSUBJECT'});
	
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_HTML -->'} = ($msgref->{'MSGFORMAT'} eq 'HTML')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_WIKI -->'} = ($msgref->{'MSGFORMAT'} eq 'WIKI')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_TEXT -->'} = ($msgref->{'MSGFORMAT'} eq 'TEXT')?'checked':'';
		$GTOOLSUI::TAG{'<!-- MSGFORMAT_DONOTSEND -->'} = ($msgref->{'MSGFORMAT'} eq 'DONOTSEND')?'checked':'';
	
		$GTOOLSUI::TAG{'<!-- MSGBODY -->'} = &ZOOVY::incode($msgref->{'MSGBODY'});
		$GTOOLSUI::TAG{'<!-- MSGFROM -->'} = &ZOOVY::incode($msgref->{'MSGFROM'});
		$GTOOLSUI::TAG{'<!-- MSGBCC -->'} = &ZOOVY::incode($msgref->{'MSGBCC'});
		$GTOOLSUI::TAG{'<!-- CREATED -->'} = &ZTOOLKIT::pretty_date($msgref->{'CREATED_GMT'},1);
	
		foreach my $mline (@SITE::EMAILS::MACRO_HELP) {
			my $show = 0;
			if ($mline->[0] eq $msgref->{'MSGTYPE'}) { $show |= 1; }
			elsif (($msgref->{'MSGTYPE'} eq 'TICKET') && ($mline->[0] eq 'CUSTOMER')) { $show |= 1; }
			elsif (($msgref->{'MSGTYPE'} eq 'TICKET') && ($mline->[0] eq 'ORDER')) { $show |= 2; } # 2 = selective availability
	
			if ($show) {
			$GTOOLSUI::TAG{'<!-- MACROHELP -->'} .= 
				sprintf(q~<tr>
				<td class="av" valign="top">%s</td>
				<td class="av" valign="top">%s%s</td>
				</tr>~,
				&ZOOVY::incode($mline->[1]), 
				$mline->[2],
				((($show&2)==2)?'<div class="hint">Note: will only appear when properly associated.</div>':'')
				 );
				}
			}
	
		$template_file = 'msgedit.shtml';	
		}
	
	##
	##
	##
	if ($VERB eq 'EDIT') {
		$template_file = 'edit.shtml';
	
		my ($SE) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE,RAW=>1);
		my $result = $SE->available("");	
		foreach my $TYPE ('ORDER','ACCOUNT','PRODUCT','TICKET') {
			my $c = '';
			my $r = 0;
			my %MSGIDS = ();
			foreach my $msgref (@{$result}) {
				next if ($TYPE ne $msgref->{'MSGTYPE'});
				$MSGIDS{ $msgref->{'MSGID'} } = $msgref;
				}
	
			## we sort by MSGID
			foreach my $k (sort keys %MSGIDS) {
				my $msgref = $MSGIDS{$k};
				my $title = "SUBJECT: $msgref->{'MSGSUBJECT'}";
				if ($msgref->{'MSGTITLE'} ne '') { $title = "TITLE: $msgref->{'MSGTITLE'}"; }
	
				if (not defined $msgref->{'MSGFORMAT'}) { $msgref->{'MSGFORMAT'} = 'HTML'; }
	
				$r = ($r eq 'r0')?'r1':'r0';
				$c .= "<tr class='$r'>";
				$c .= "<td width='50px'><input type='button' class='button' value=' Edit ' onClick=\"navigateTo('/biz/vstore/builder/emails/index.cgi?DOMAIN=$DOMAIN&VERB=MSGEDIT&MSGID=$msgref->{'MSGID'}');\"></td>";
				$c .= "<td width='100px'>".&ZOOVY::incode($msgref->{'MSGID'})."</td>";
				$c .= "<td>".&ZOOVY::incode($title)."</td>";
				if (not defined $msgref->{'CREATED_GMT'}) { $msgref->{'CREATED_GMT'} = 0; }
				$c .= "<td width='100px'>".&ZTOOLKIT::pretty_date($msgref->{'CREATED_GMT'})."</td>";
				$c .= "<td width='100px'>".$msgref->{'MSGFORMAT'}."</td>";
				$c .= "</tr>";
				}
			$GTOOLSUI::TAG{"<!-- $TYPE -->"} .= $c;
			}
		# $GTOOLSUI::TAG{'<!-- ORDER -->'} = Dumper($result);
	
		}
	
	if ($VERB eq 'ADD') {
		$GTOOLSUI::TAG{'<!-- NS -->'} = $NS;
		$template_file = 'add.shtml';
		}
	
	
	#push @TABS, { name=>'Config', link=>"/biz/vstore/builder/emails/index.cgi?VERB=CONFIG", selected=>(($VERB eq 'SELECT')?1:0) };
	push @TABS, { name=>'Select', link=>"/biz/vstore/builder/themes/index.cgi?SUBTYPE=E&DOMAIN=$DOMAIN", selected=>(($VERB eq 'SELECT')?1:0) };
	push @TABS, { name=>'Edit', link=>"/biz/vstore/builder/emails/index.cgi?VERB=EDIT&DOMAIN=$DOMAIN", selected=>(($VERB eq 'EDIT')?1:0)  };
	push @TABS, { name=>'Add', link=>"/biz/vstore/builder/emails/index.cgi?VERB=ADD&DOMAIN=$DOMAIN", selected=>(($VERB eq 'ADD')?1:0)  };
	
	my @BC = ();
	push @BC, { name=>"Setup", link=>'/biz/vstore' };
	push @BC, { name=>"Builder", link=>'/biz/vstore/builder' };
	push @BC, { name=>"Emails", link=>'/biz/vstore/builder/emails' };
	
	return(file=>$template_file,header=>1,msgs=>\@MSGS,tabs=>\@TABS, bc=>\@BC);
	



	#!/usr/bin/perl
	
	use lib "/backend/lib";
	use ZOOVY;
	use CGI;
	
	my $q = new CGI;
	my $ID = $ZOOVY::cgiv->{'id'};
	
	print "Content-type: text/html\n\n";
	print qq~
	<html>
	<head>
	<title>Zoovy HTML Editor</title>
	
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	
	<!-- Configure the path to the editor.  We make it relative now, so that the
	    example ZIP file will work anywhere, but please NOTE THAT it's better to
	    have it an absolute path, such as '/htmlarea/'. -->
	<script type="text/javascript">
	  _editor_url = "/biz/vstore/builder/htmlarea/";
	  _editor_lang = "en";
	</script>
	
	<!-- load the main HTMLArea file, this will take care of loading the CSS and
	    other required core scripts. -->
	<script type="text/javascript" src="/biz/vstore/builder/htmlarea/htmlarea.js"></script>
	
	<!-- load the plugins -->
	<script type="text/javascript">
	      // WARNING: using this interface to load plugin
	      // will _NOT_ work if plugins do not have the language
	      // loaded by HTMLArea.
	
	      // In other words, this function generates SCRIPT tags
	      // that load the plugin and the language file, based on the
	      // global variable HTMLArea.I18N.lang (defined in the lang file,
	      // in our case "lang/en.js" loaded above).
	
	      // If this lang file is not found the plugin will fail to
	      // load correctly and NOTHING WILL WORK.
	
	      HTMLArea.loadPlugin("TableOperations");
	      HTMLArea.loadPlugin("SpellChecker");
	      HTMLArea.loadPlugin("FullPage");
	      HTMLArea.loadPlugin("CSS");
	      HTMLArea.loadPlugin("ContextMenu");
	      //HTMLArea.loadPlugin("HtmlTidy");
	      HTMLArea.loadPlugin("ListType");
	      HTMLArea.loadPlugin("CharacterMap");
			HTMLArea.loadPlugin("DynamicCSS");
	</script>
	
	<style type="text/css">
	html, body {
	  font-family: Verdana,sans-serif;
	  background-color: #FFFFFF;
	  color: #000000;
	}
	a:link, a:visited { color: #00f; }
	a:hover { color: #048; }
	a:active { color: #f00; }
	
	textarea { background-color: #fff00f; border: 1px solid; }
	</style>
	
	<script type="text/javascript">
	var editor = null;
	
	function initEditor() {
	
	  // create an editor for the "ta" textbox
	  editor = new HTMLArea("ta");
	
	  // register the FullPage plugin
	  editor.registerPlugin(FullPage);
	
	  // register the Table plugin
	  editor.registerPlugin(TableOperations);
	
	  // register the SpellChecker plugin
	  editor.registerPlugin(SpellChecker);
	
	  // register the HtmlTidy plugin
	  //editor.registerPlugin(HtmlTidy);
	
	  // register the ListType plugin
	  // editor.registerPlugin(ListType);
	
	//  editor.registerPlugin(CharacterMap);
	// editor.registerPlugin(DynamicCSS);
	
	  // register the CSS plugin
	  editor.registerPlugin(CSS, {
	    combos : [
	      { label: "Syntax:",
	                   // menu text       // CSS class
	        options: { "None"           : "",
	                   "Code" : "code",
	                   "String" : "string",
	                   "Comment" : "comment",
	                   "Variable name" : "variable-name",
	                   "Type" : "type",
	                   "Reference" : "reference",
	                   "Preprocessor" : "preprocessor",
	                   "Keyword" : "keyword",
	                   "Function name" : "function-name",
	                   "Html tag" : "html-tag",
	                   "Html italic" : "html-helper-italic",
	                   "Warning" : "warning",
	                   "Html bold" : "html-helper-bold"
	                 },
	        context: "pre"
	      },
	      { label: "Info:",
	        options: { "None"           : "",
	                   "Quote"          : "quote",
	                   "Highlight"      : "highlight",
	                   "Deprecated"     : "deprecated"
	                 }
	      }
	    ]
	  });
	
	  // add a contextual menu
	  editor.registerPlugin("ContextMenu");
	
	  // load the stylesheet used by our CSS plugin configuration
	  editor.config.pageStyle = "@import url(custom.css);";
	
	  editor.generate();
	  return false;
	}
	
	HTMLArea.onload = initEditor;
	
	function insertHTML() {
	  var html = prompt("Enter some HTML code here");
	  if (html) {
	    editor.insertHTML(html);
	  }
	}
	function highlight() {
	  editor.surroundHTML('<span style="background-color: yellow">', '</span>');
	}
	</script>
	
	</head>
	
	<!-- use <body onload="HTMLArea.replaceAll()" if you don't care about
	     customizing the editor.  It's the easiest way! :) -->
	<body onload="HTMLArea.init();">
	<form action="#" name="edit" id="edit" method="POST">
	
	<textarea id="ta" name="ta" style="width:100%" rows="20" cols="80">
	</textarea>
	
	<p />
	
	<center><table width=90%>
	<tr>
		<td>
			<input type="submit" src="/images/bizbuttons/save.gif" onClick="mySubmit();" name="ok" value="  submit  " />
		</td>
		<td width=100% align='right'>
			<input type="button" name="ins" value="  insert html  " onclick="return insertHTML();" />
		</td>
	</tr>
	</table>
	</center>
	
	<!--
	<input type="button" name="hil" value="  highlight text  " onclick="return highlight();" />
	-->
	
	
	<script type="text/javascript">
	<!--
	
	
	function mySubmit() {
	
		// document.edit.save.value = "yes";
		document.edit.onsubmit(); 	
		document.edit.submit();
		var v = document.forms['edit'].ta.value;
	
		window.opener.document.getElementById('$ID').value = v;
		window.close();
		return(1);
		};
	
	
	var frm = window.opener.document.forms['thisFrm'];
	if (!frm) { frm = window.opener.document.forms['thisFrm-$ID']; }
	ta.value = frm.elements['$ID'].value;
	
	//-->
	</script>
	
	</form>
	</td></tr></table>
	</center>
	
	</body>
	</html>
	~;
	
	
	