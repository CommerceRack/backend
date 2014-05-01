package APPTIMIZER;

use lib "/httpd/modules";
use HTML::TreeBuilder;
use HTTP::Tiny;
use IO::Scalar;
use JavaScript::Minifier;
use MIME::Types;
use Data::Dumper;
use MIME::Base64;
use CSS::Minifier::XS;
use CSS::Inliner::Parser;
use URI::URL;

sub optimizeHTML {
	my ($NFSROOT, $el, $CONFIG) = @_;

	if (my $cmds = $el->attr('data-apptimize')) {
		$cmds =~ s/^[\s]+//gs;
		$cmds =~ s/[\s]+$//gs;

		my $BODY = undef;
		my %CMDS = ();
		foreach my $cmd (split(/[\s]*;[\s]*/,$cmds)) {
			$CMDS{$cmd}++;
			}

		my $src = $el->attr('src');
		if ($el->tag() eq 'link') { $src = $el->attr('href'); }	## <link rel="stylesheet" type="text/css" href="app-quickstart.css"

		if (($CMDS{'embed'} || $CMDS{'download'}) && ($src =~ /^http[s]?:/)) {
			print STDERR "Downloading $src\n";
			my $response = HTTP::Tiny->new->get($src);
			if ($response->{'success'}) {
				$BODY = $response->{'content'};
				}
			$el->attr('data-debug',sprintf("[remote] tag:%s type:%s",$el->tag(), $el->attr('type')));
			}

		if (($CMDS{'embed'}) && (not defined $BODY) && ($src)) {
			if (($src ne '') && (-f "$NFSROOT/$src"))  {
				open F, "<$NFSROOT/$src"; while(<F>) { $BODY .= $_; } close F;
				}
			$el->attr('data-debug',sprintf("[local] tag:%s type:%s",$el->tag(), $el->attr('type')));
			}
	
		if ($BODY && ($el->tag() eq 'img')) {
			my $src = $el->attr('src');
			$el->attr('data-embedded',"$src");
			my ($mime_type, $encoding) = MIME::Types::by_suffix($src);
			$el->attr('src',sprintf("data:%s;%s,%s",$mime_type, $encoding, MIME::Base64::encode_base64($BODY,'') ) );
			}

		if ($BODY && ($el->tag() eq 'script') && ($el->attr('type') eq 'text/javascript')) {
			## <script>
			if ($src =~ /[\.-]min\.js$/) {
				}
			else {
				print STDERR "Minifiy JS ($src)\n";
				my $COPY = '';
				my $SH = new IO::Scalar \$COPY;
				JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$CONFIG->{'copyright'});
				$BODY = $COPY;
				}

			$el->push_content($BODY);	
			$el->attr('src',undef);
			$el->attr('data-embedded',"$src");					
			}

		
		if ($BODY && ($el->tag() eq 'link') && ($el->attr('type') eq 'text/css')) {
			## 
			my $css = CSS::Inliner::Parser->new(); $css->read( {css=>$BODY} );
			foreach my $rule (@{$css->get_rules()}) {
				 foreach my $k (keys %{$rule->{'declarations'}}) {
					if ($rule->{'declarations'}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
						## print STDERR "K:$k\n";
						my $url = $1;
						$url =~ s/^'(.*)'$/$1/gs;	## strip outer ' 
						$url =~ s/^"(.*)"$/$1/gs;	## strip outer ' 
						my $absurl = URI::URL->new($url,$src)->abs();
						print STDERR "--> absurl: $absurl\n";
						if (-f "$NFSROOT/$absurl") {
							my ($DATA) = ''; 
							open F, "<$NFSROOT/$absurl"; while(<F>) { $DATA .= $_; } close F;
							my ($mime_type, $encoding) = MIME::Types::by_suffix($absurl);
							$absurl = sprintf("data:%s;base64,%s",$mime_type,MIME::Base64::encode_base64($DATA,''));
							}
						$rule->{'declarations'}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
						}
					}
				## this will output uncompressed html with embedded url's
				$BODY = $css->write();
				}

#			# open F, ">/tmp/css"; print F Dumper($CSS); close F;
#			if ((not defined $CSS) || (ref($CSS) ne 'CSS::Tiny')) {
#				$el->postinsert("<!-- // style is not valid, could not be interpreted by CSS::Tiny // -->");
#				}
#			else {
#				$sheet = $CSS->html();
#				my $sheetnode = HTML::Element->new('style','type'=>'text/css');
#				$sheetnode->push_content("<!-- \n".$CSS->write_string()."\n -->");
#				$el->replace_with($sheetnode);
#				}
#			}
				

			print STDERR "Minifiy CSS ($src)\n";
			eval { $BODY = CSS::Minifier::XS::minify($BODY); };
			if ($@) {
					$BODY = "/* 
CSS::Minifier::XS error: $@
please use http://jigsaw.w3.org/css-validator/validator to correct, or disable css minification. 
*/\n".$BODY;
				}

			$el->tag('style');
			$el->attr('href',undef);
			$el->push_content($BODY);
			$el->attr('data-embedded',"$src");
			}

		# $el->attr('data-apptimize',undef);
		}

	if (defined $el) {
	   foreach my $elx (@{$el->content_array_ref()}) {
			if (ref($elx) eq '') {
				## just content!
				}
			else {
				&APPTIMIZER::optimizeHTML($NFSROOT, $elx, $CONFIG);
	         }
			}
		}
	
	return($el);
	}

##
###
sub debug {
	my ($PATH, $FILE) = @_;

	my %CONFIG = ();

	open F, "<$PATH/$FILE";
	while (<F>) { $BODY .= $_; }
	close F;

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>0,ignore_unknown=>0,store_declarations=>1,store_comments=>0); # empty tree
	$tree->parse_content($BODY);
	my $el = $tree->elementify();
	&APPTIMIZER::optimizeHTML($PATH,$el,\%CONFIG);
	$BODY = $el->as_HTML();
	return($BODY);
	}


1;
