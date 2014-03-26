package TLC;

use strict;
use warnings;
use Data::Dumper;
use JSON::Path;
use Mojo::DOM;
use Pegex;
use Pegex::Tree::DataTLC;
use POSIX qw(strftime);
use JSON::XS;

require ZOOVY;

our $VERSION = '1.00';
our $TLC_GRAMMAR = q!
##
## https://github.com/zoovy/AnyCommerce-Development/blob/201402/resources/pegjs-grammar-20140203.pegjs
## A simple grammar for the data-tlc language.
## For parser implementation that use this grammar, see ./parse.pl perl code.

## If you want to read this syntax and understand what's going on below, read this tutorial first:
## http://search.cpan.org/~ingy/Pegex-0.21/lib/Pegex/Tutorial/JSON.pod
## https://github.com/ingydotnet/pegex-pm/blob/master/examples/calculator1.pl

%grammar data-tlc
%version 1.0

## ** DATA-TLC**
## data-tlc is either 'if-statement', 'bind-statement' or 'command', separated by semi-solons (;)
## the last semi-colon is optional (in Pegex %% defines that optional alternation)
data-tlc: (jscomment | if-statement | while-statement | foreach-statement | set-statement | bind-statement | command)+ %% <lb>*


## ** BIND-STATEMENT **
## bind $var 'something';    (jsonpath lookup)
## bind $var $someothervar;  (jsonpath lookup)
## bind $var ~tag;           (returns tag id/path)
## bind ~tag '#tagid';       jQuery('#tagid')
## bind ~tag $tagid;          jQuery($tagid)
bind-statement: /~bind~/ (variable | tag) /~/ (variable | scalar | tag)
## set $var 'something'
## set $var $copy;
set-statement: /~set~/ (variable | tag) /~/ (variable | scalar | tag | integer | boolean | hexcolor | tag) /~/ value* % /~/

## ** IF/WHILE-STATEMENT **
## if(cond) {{ command1 }} else {{ command2 }}
## while(cond) {{ command1 }}
## block: /{{~/ (block | set-statement | bind-statement | command)+ %% /~<SEMI>~/ /~}}/ 
## block: /{{~/ <lb>* (data-tlc)+ %% /~<SEMI>~/ <lb>* /~}}/ 
## foreach $item in $items {{ command1; }}
cmdline: (set-statement | bind-statement | if-statement | foreach-statement | while-statement | command)+ %% /~<SEMI>~/
block: /{{~/ ( jscomment | cmdline )+ /~}}/ 
while-statement: /~while~/ /<LPAREN>~/ command /~<RPAREN>~/ block 
if-statement: /~if~/ /<LPAREN>~/ command /~<RPAREN>~/ block (/~else~/ block)?
foreach-statement: /~foreach~/ (variable) /~in~/ (variable) /~/ block

## ** COMMAND **
## module_name#command_name --opts=...
command: /~ (([A-Za-z0-9_]+)#)?([A-Za-z0-9_]+) ~/ value* % /~/

## ** DATA TYPES **
value: longopt | variable | integer | scalar | boolean | tag | hexcolor

longopt: /--([a-zA-Z][a-z0-9A-Z\-]+)=/ value | /--([a-zA-Z][a-z0-9A-Z\-]+)/
variable: /\$([A-Za-z_][A-Za-z0-9_]*)/
integer: /~(<DASH>?<DIGIT>+)~/
scalar: /'([^']*)'/         # not yet allows escaped single quotes inside
boolean: /(true|false)/

## ~tag is a reference to a jquery object 
## tag table should maintain reference to tags on DOM
tag: /\~([A-Za-z0-9\-_]+)/

hexcolor: /#([A-Fa-f0-9]{6})/
## ** END DATA TYPES **

jscomment: /~<SLASH><STAR>.*?<STAR><SLASH>~/
lb: /~<SEMI>~/|/~<EOL>~/

!;

%TLC::IMAGE_ATTR_LOOKUP = (
	## tlc parameter --bgcolor  =>    <img data-bgcolor="">
	'src'=>'src',
	'width'=>'width',
	'height'=>'height',
	'bgcolor'=>'data-bgcolor',
	'minimal'=>'data-minimal',
	'media'=>'data-media',
	'alt'=>'alt',
	);


our $TLC_RECEIVER = 'Pegex::Tree::DataTLC';

=head1 NAME

Server-Side TLC - parse/run data-tlc commands + render html containing data-tlc blocks in Perl.

=head1 SYNOPSIS

  use TLC;
  
  my $tlc = TLC->new();
  my $input_html = q~<h1 data-tlc="bind $var '$.TITLE'; apply --append;"></h1>~;
  my $input_data = { TITLE => 'Hello there!' }
  
  ## take html, find and run all data-tlc blocks, modify html and return it.
  my $result_html = $tlc->render_html($input_html, $input_data);
  
Also it's possible to pass and run data-tlc commands one by one manually.
See 'parse' and 'run' methods.
=cut


=method new
my $tlc = TLC->new();
=cut
sub new {
	my ($class, %params) = @_;
	

	## load DataTLC pegex grammar
	$params{username} ||= undef;
	$params{grammar}	||= $TLC_GRAMMAR;
	$params{parser}	 ||= pegex($params{grammar}, $TLC_RECEIVER);
	$params{maxloops}	||= 1000;		## maximum number of times a while loop can run

	$params{dom} ||= undef;	# Mojo::Dom reference	
	$params{cwt} ||= undef;	# reference to a tag within Mojo::Dom
	$params{data} ||= {};
	$params{'%TEMPLATES'} ||= {};
	
	$params{vars} = {}; ## all BIND commands will store variables here
	
	bless \%params, $class;
}

sub username { return($_[0]->{'username'}); }

## sets/returns the cwt (current working tag)
sub _cwt { 
	if (defined $_[1]) { $_[0]->{'cwt'} = $_[1]; } 
	return($_[0]->{'cwt'}); 
	}

sub _vars { 
	if (defined $_[1]) { $_[0]->{'vars'} = $_[1]; } 
	return($_[0]->{'vars'}); 
	}

## sets/returns the Mojo::Dom object
sub _dom { 
	if (defined $_[1]) { $_[0]->{'dom'} = $_[1]; } 
	return($_[0]->{'dom'}); 
	}

sub _templates {	
	if (defined $_[1]) { $_[0]->{'%TEMPLATES'} = $_[1]; } 
	return($_[0]->{'%TEMPLATES'}); 
	}

## returns a specific template id.
sub template {
	return($_[0]->{'%TEMPLATES'}->{ $_[1] });
	}

## sets/returns the data object associated with the TLC (used for jsonpath queries)
sub _data { 
	if (defined $_[1]) { $_[0]->{'data'} = $_[1]; } 
	return($_[0]->{'data'}); 
	}

=method render_html
my $result_html = $tlc->render_html($html, $input_data);

Takes HTML chunk with embedded data-tlc commands + perl data structure
(cart object, array of products, single product hr), then parses HTML using Mojo::DOM,
finds all data-tlc blocks, parses them using Pegex::Tree::DataTLC + DataTLC.pgx,
and executes all commands - renderring html (by modifying Mojo::DOM object)

Mojo::DOM is very similar to jquery object - it can find nodes ($dom->find('id')),
can extract attributes - $dom->attr('data-tlc')
Mojo::Collection has 'each' method - $dom->find('*[data-tlc]')->each(sub { my ($e, $count) = @_; })
Really easy to use. Requires Mojolicious >= 4.00!!!

JSON::Path is used to traverse passed input data structure 
and to extract the actual data into html nodes.

Server-side TLC can be used to generate emails/push notification 
from html templates containing data-tlc

Returns ready to use HTML string
=cut
sub render_html {
	my ($self, $html, $data) = @_;
	
	my $dom = Mojo::DOM->new();
	$dom->parse($html);
	$self->_dom($dom);
	if (defined $data) { $self->_data($data); }

	$dom->find('template')->each(sub {
		my ($e, $count) = @_;
		my $dom = $e->children();
		$self->_templates()->{ $e->{id} } = "$dom";	## store a string verion of a template
		$e->remove();
		});

	## find all nodes having data-tlc attribute
	$dom->find('*[data-tlc]')->each(sub {
		my ($e, $count) = @_;
		#print $e->attr('data-tlc')."\n";

		next if ($e->type() eq 'template');

		$self->_cwt($e);
		## parse and run data-tlc block, modifying $dom object on the fly
		$self->run($e->attr('data-tlc'));
		
		## this data-tlc block is processed - let's delete it
		$e->attr('data-tlc' => undef);
		});
	
	## dump resulting html as string
	my $res = "$dom";
	$res =~ s/\s*data-tlc//gs;
	return $res;
}


=method parse
my $commands = $tlc->parse($tlc_expr);

Parses data-tlc expressions, returns err + structure (arrayref with commands)
=cut
sub parse {
	my ($self, $expr) = @_;
	my $commands = [];
	
	if($expr) {
		$commands = eval { $self->{parser}->parse($expr) };
		print STDERR "$expr\n$@\n" if $@;
	}

	return $commands;
}


=method run
$tlc->run($tlc_expr, $input_data);

Takes tlc expression (from $self->_cwt()->attr('data-tlc')), parses and runs it, 
modifying Mojo::DOM object (html structure) on the fly.
$input_data is a product/category/cart object, etc. - some data we'll be inserting into html

Method returns nothing, but modifies $dom object.
=cut
sub run {
	my ($self, $expr, $data) = @_;

	my $data_was = undef;
	if (defined $data) {
		$data_was = $self->_data();
		$self->_data($data);
		}

	my $commands = $self->parse($expr);

	$self->{vars} = {}; ## reset vars
	$self->handle_block({statements => $commands});
	
	if (defined $data_was) { $self->_data($data_was); }
	#print Dumper($self->{vars});
	}








######## data-tlc statement/command handlers ########

=method handle_block
Handler for 'type'=>'block' (one or several commands)
=cut
sub handle_block {
	my ($self, $block) = @_;
	
	## print Dumper($blocks);
	foreach my $c (@{$block->{'statements'}}) {
		if (ref($c) eq 'ARRAY') {
			## nested command block (usually from inside a block)
			$self->handle_block( { 'statements'=>$c } );
			}
		else {
			$self->handle_if($c)				 if $c->{type} eq 'IF';
			$self->handle_while($c)			if $c->{type} eq 'WHILE';
			$self->handle_foreach($c)			if $c->{type} eq 'FOREACH';
			$self->handle_bind($c)			 if $c->{type} eq 'BIND';
			$self->handle_set($c)			 if $c->{type} eq 'SET';
			$self->handle_command($c)		if $c->{type} eq 'command';
			}
		}
	}


## sub core_bind { my ($self) = shift @_; return($self->handle_bind(@_)); }

=method handle_bind
Define/set variable in $self->{vars} hash
=cut
sub handle_bind {
	my ($self, $command) = @_;
	
	## print 'BIND: '.Dumper($command)."\n";
	## step1: resolve the 'Src'
	## print Dumper($command);

	my $src = undef;
	my $result = undef;

	if ($command->{'Set'}->{'type'} eq 'tag') {
		## bind a tag
		if ($command->{Src}->{type} eq 'variable') {
			## resolve the src from a variable (versus a scalar)
			$src = $self->lookup_value( $command->{Src} );
			}
		else {
			## it's a scalar
			$src = $command->{Src}{value};
			}

		$result = $self->_cwt()->find($src);
		}
	else {
		## variable
		if ($command->{Src}->{type} eq 'variable') {
			## resolve the src from a variable (versus a scalar)
			$src = $self->lookup_value( $command->{Src} );
			}
		else {
			## it's a scalar
			$src = $command->{Src}{value};
			}

		if (substr($src,0,1) eq '.') {
			## this is pretty messed up!
			## print "JSONPATH: \$$src\n";
			## print Dumper($self->_data());
			my $jpath = JSON::Path->new( '$'.$src );
			$result = $jpath->value($self->_data());
			## print "RESULT: $result\n";
			} 
		else {
			$result = $command->{Src}{value};
			}
		}
	
	## default value is like $_ in perl
	## if we have a chain of commands without arguments - this is our default argument (last set variable)
	return( $self->{vars}{default} = $self->{vars}{$command->{Set}{value}} = $result );
}


=method handle_set
Define/set variable in $self->{vars} hash
=cut
sub handle_set {
	my ($self, $command) = @_;
	
	## print 'BIND: '.Dumper($command)."\n";
	## step1: resolve the 'Src'

	my $src = undef;
	if ($command->{Src}->{type} eq 'variable') {
		## resolve the src from a variable (versus a scalar)
		$src = $self->lookup_value( $command->{Src} );
		}
	else {
		## it's a scalar
		$src = $command->{Src}{value};
		}

	my $result = $src;

	if (defined $command->{args}) {
		for my $arg (@{$command->{args}}) {
			if ($arg->{'key'} eq 'path') {
				my $path = $self->lookup_value($arg->{'value'});
				my $jpath = JSON::Path->new('$'.$path);
		 		$result = $jpath->value($result);
				}
			elsif ($arg->{'key'} eq 'split') {	
				my $token = $self->lookup_value($arg->{value}) || '|';
				$token = quotemeta($token);
				$result = [ split("$token",$result) ];
				}
			elsif ($arg->{'key'} eq 'stringify') {
				$result = Data::Dumper::Dumper($result);
				}
			}
		
		}

	## default value is like $_ in perl
	## if we have a chain of commands without arguments - this is our default argument (last set variable)
	return( $self->{vars}{default} = $self->{vars}{$command->{Set}{value}} = $result );
}


=method handle_if
IF ELSE structure handler
=cut
sub handle_if {
	my ($self, $command) = @_;
	
	if($self->handle_command($command->{When})) {
		$self->handle_block($command->{IsTrue});
	} else {
		$self->handle_block($command->{IsFalse});
	}
}

=method handle_while
WHILE structure handler
=cut
sub handle_while {
	my ($self, $command) = @_;
	
	my $loop_max = $self->{'maxloops'};
	while ($self->handle_command($command->{When})) {
		$self->handle_block($command->{Loop});

		last if (--$loop_max < 0);
		}
	}

=method handle_foreach
WHILE structure handler
=cut
sub handle_foreach {
	my ($self, $command) = @_;
	
	my $set = $command->{'Set'}->{'value'};
	my $members = $self->{vars}->{ $command->{'Members'}->{'value'} };
	if (not defined $members) { $members = []; }
	if (ref($members) ne 'ARRAY') { $members = []; }

	foreach my $item (@{$members}) {
		$self->{vars}->{$set} = $item;
		$self->handle_block($command->{Loop});
		}
	}



=method handle_command
Handler for 'type'=>'command'
It extracts command module + command name and executes it
=cut
sub handle_command {
	my ($self, $command) = @_;
	
	my $cmd = "$command->{module}_$command->{name}";
	print STDERR "TLC.pm - command '$cmd' is not yet defined\n" unless $self->can($cmd);
	
	return $self->$cmd($command) if $self->can($cmd); ## for example, $cmd can be 'core_apply'
}


=method lookup_value
$self->lookup_value({type => 'variable', value => '$.TITLE'}); ## returns $self->_data()->{TITLE}
$self->lookup_value(undef);																		## returns $self->{vars}{default}
$self->lookup_value({type => 'integer', value => '5'});				## returns '5' (same for hexcolor, scalar, boolean)
=cut
sub lookup_value {
	my ($self, $val) = @_;

 ## print "HANDLING VALUE: ".Dumper($val,$data)."\n";
	
	return $self->{vars}{default} unless $val;

	if ($val->{type} eq 'variable') {
		return($self->{vars}->{$val->{'value'}});
		## NOT SURE WHY WE'D EVER USE JSONPATH TO LOOKUP A VARIABLE
		#my $jpath = JSON::Path->new($val->{value});
	 	#return $jpath->value($data);
		}
	
	if ($val->{type} =~ /^scalar$|^integer$|^hexcolor$|^boolean$/i) { return $val->{value}	};
	}




####################################
## core commands

sub core_stringify {
	my ($self, $command) = @_;

	my $var = undef;
	for my $arg (@{$command->{args}}) {
		if ($arg->{'type'} eq 'variable') { 
			$var = $self->{vars}->{ $arg->{'value'} };
			}
		}
	## $var = JSON::XS->new()->pretty()->allow_nonref()->convert_blessed()->encode($var);
	$var = Data::Dumper::Dumper($var);

	$self->{vars}{default} = $var;
	return($var);
	}


sub core_transmogrify {
	my ($self, $command) = @_;

#          'args' => [
#                      {
#                        'value' => 'binditemto',
#                        'type' => 'variable'
#                      },
#                      {
#                        'value' => {
#                                     'value' => 'skuTemplate',
#                                     'type' => 'scalar'
#                                   },
#                        'type' => 'longopt',
#                        'key' => 'templateid'
#                      }
#                    ],
#          'name' => 'transmogrify',
#          'type' => 'command',
#          'module' => 'core'

	my $template = undef;

	my $dataset = $self->_data();
	my $result = $self->{vars}{default};
	my $html = undef;
	my $var = undef;

	for my $arg (@{$command->{args}}) {
		if ($arg->{'type'} eq 'variable') { 
			$dataset = $self->{vars}->{ $arg->{'value'} };
			}
		elsif ($arg->{'key'} eq 'templateid') {
			my $id = $self->lookup_value($arg->{value});
			$html = $self->_templates()->{ $id };
			}
		elsif ($arg->{'key'} eq 'template') {
			$html = $self->lookup_value($arg->{value});
			}
		elsif ($arg->{'key'} eq 'dataset') {
			$dataset = $self->lookup_value( $arg->{value}); 
			}
		}

	my $_vars_ = $self->_vars();
	my $_cwt_ = $self->_cwt();		# backup cwt
	my $_data_ = $self->_data();		# backup data
	my $_dom_ = $self->_dom();

	($result) = $self->render_html( $html, $dataset );

	$self->_cwt($_cwt_);
	$self->_data($_data_);
	$self->_dom($_dom_);
	$self->_vars($_vars_);

	$self->{vars}{default} = $result;
	return($result);
	}

##
## export --key'%something' --value=$value
##
sub core_export {
	my ($self, $command) = @_;

	my ($path,$dataset) = (undef,undef);
	
	my $var = undef;
	for my $arg (@{$command->{args}}) {
		if ($arg->{'type'} eq 'variable') { 
			$path = $self->{vars}->{ $arg->{'value'} };
			}
		elsif ($arg->{'type'} eq 'key') {
			$path = $self->lookup_value($arg->{'value'});
			}
		elsif ($arg->{'type'} eq 'dataset') {
			$dataset = $self->lookup_value($arg->{'value'});
			}
		}

	my $result = undef;
	if ($var) { $self->{vars}->{$var} = $result; }
	if ($path) { 
		my $jpath = JSON::Path->new( '$'.$path );
		$result = $jpath->value($dataset || $self->_data());
		}

	return($result);
	}



sub core_math {
	my ($self, $command) = @_;
	
	my $var = undef;
	my $result = $self->{vars}{default};
	for my $arg (@{$command->{args}}) {
		if ($arg->{'type'} eq 'variable') { 
			$var = $arg->{'value'};
			$result = $self->{vars}->{ $var };
			}
		elsif ($arg->{'key'} eq 'add') {
			$result = $self->lookup_value($arg->{value}) + $result;
			}
		elsif ($arg->{'key'} eq 'sub') {
			$result = $result - $self->lookup_value($arg->{value});
			}
		elsif (($arg->{'key'} eq 'multiply') || ($arg->{'key'} eq 'mult')) {
			$result = $result * $self->lookup_value($arg->{value});
			}
		elsif (($arg->{'key'} eq 'divide') || ($arg->{'key'} eq 'div')) {
			$result = $result / $self->lookup_value($arg->{value});
			}
		elsif ($arg->{'key'} eq 'precision') {
			my $sprintf = sprintf("%%0.%df",int($self->lookup_value($arg->{value})));
			$result = sprintf($sprintf,$result);
			}
		else {
			warn "bad math: ".Dumper($arg);
			$result = undef;
			}
		}
	## print "RESULT: $result\n";

	if ($var) { $self->{vars}->{$var} = $result; }
	return( $self->{vars}{default} = $result );
	}

sub core_is {
	my ($self, $command) = @_;
	#print STDERR Dumper($command);
	
	## if(is $var --notblank) 
	my $var = undef;
	my $val = $self->{vars}{default};
	my $val2 = undef;
	my $result = -1;

	## print 'ARGS: '.Dumper($command->{args});
	for my $arg (@{$command->{args}}) {
		## format --prepend, --currency
		if ($arg->{'type'} eq 'variable') { 
			$val = $self->lookup_value( $arg );
			## print Dumper($arg,$self->{vars});
			## print Dumper($arg,$result); die();
			}
		elsif (($arg->{'key'} eq 'notblank') || ($arg->{'key'} eq 'blank')) {
			$val2 = $val;
			if (defined $arg->{'value'}) { $val2 = $self->lookup_value($arg->{'value'}); }
			if (not defined $val2) { $val2 = ''; }
			$result = ($val2 ne '');
			if ($arg->{'key'} eq 'blank') { $result = (! $result); }
			}
		elsif (($arg->{'key'} eq 'lt') || ($arg->{'key'} eq 'gt')) {
			if (defined $arg->{'value'}) { $val2 = $self->lookup_value($arg->{'value'}); }
			## print STDERR "BAD_MATH: /$arg->{'key'}/ $val < $val2\n";
			$result = ($val < $val2);
			if ($arg->{'key'} eq 'gt') { $result = (! $result); }
			}
		elsif (($arg->{'key'} eq 'eq') || ($arg->{'key'} eq 'ne')) {
			if (defined $arg->{'value'}) { $val2 = $self->lookup_value($arg->{'value'}); }
			## print STDERR "BAD_MATH: /$arg->{'key'}/ $val < $val2\n";
			if (not defined $val2) { $val2 = ''; }
			$result = ($val eq $val2);
			if ($arg->{'key'} eq 'ne') { $result = (! $result); }
			}
		elsif ($arg->{'key'} eq 'templateidexist') {
			$val2 = $self->lookup_value($arg->{'value'}); 
			$result = (defined $self->{'%TEMPLATES'}->{$val2})?1:0;
			}
		else {
			## print Dumper($command);
			warn "'is' against unmatched: ".Dumper($command)."\n";
			}
		}

	return($result);
}

sub core_apply {
	my ($self, $command) = @_;
	

	my $new = undef;
	for my $arg (@{$command->{args}}) {
		## apply --empty, --remove, --append, --prepend, --replace
		## $self->_cwt() is Mojo::DOM object - almost like jquery
		## print Dumper($arg);
		if ($arg->{type} eq 'variable') {
			die();
			}
		elsif (($arg->{key} eq 'img') || ($arg->{key} eq 'imageurl') || ($arg->{key} eq 'imageattr')) {
			my $type = $arg->{key};
			## compile all parameters into an array
			my %TLCPARAM = ();

			$TLCPARAM{'media'} = $self->{var}->{default};
			for my $arg (@{$command->{args}}) {
				if ($arg->{'key'} eq 'imgdefault') {
					my $cwt = $self->_cwt();
					if ($arg->{'value'}) { $cwt = $self->lookup_value($arg->{value}); }
					$TLCPARAM{'height'} ||= $self->_cwt()->attr('height');
					$TLCPARAM{'width'} ||= $self->_cwt()->attr('width');
					$TLCPARAM{'bgcolor'} ||= $self->_cwt()->attr('data-bgcolor');
					$TLCPARAM{'minimal'} ||= $self->_cwt()->attr('data-minimal');
					$TLCPARAM{'media'} ||= $self->_cwt()->attr('data-media');
					}

				$TLCPARAM{ $arg->{key} } = $self->lookup_value($arg->{value});
				}

			## strip leading # from bgcolor			
			if (substr($TLCPARAM{'bgcolor'},0,1) eq '#') { $TLCPARAM{'bgcolor'} = substr($TLCPARAM{'bgcolor'},1); }

#			$TLCPARAM{'W'} = $TLCPARAM{'width'};
#			$TLCPARAM{'H'} = $TLCPARAM{'height'};
#			$TLCPARAM{'B'} = $TLCPARAM{'bgcolor'};
			if (not defined $TLCPARAM{'src'}){
				$TLCPARAM{'src'} = &ZOOVY::mediahost_imageurl($self->username(),$TLCPARAM{'media'},$TLCPARAM{'height'},$TLCPARAM{'width'},$TLCPARAM{'bgcolor'},$TLCPARAM{'ssl'},$TLCPARAM{'ext'},$TLCPARAM{'v'});
				}
			
			if ($arg->{key} eq 'imageattr') {
				foreach my $k (keys %TLC::IMAGE_ATTR_LOOKUP) {
					next if (not defined $TLCPARAM{$k}); 
					$self->_cwt()->attr( $TLC::IMAGE_ATTR_LOOKUP{$k} => $TLCPARAM{$k} );
					}
				$new = $self->_cwt();
				}
			elsif (($arg->{key} eq 'img') || ($arg->{key} eq 'imagetag')) {
				$new = "<img ";
				foreach my $k (keys %TLC::IMAGE_ATTR_LOOKUP) {
					next if (not defined $TLCPARAM{$k}); 
					$new .= "$TLC::IMAGE_ATTR_LOOKUP{$k}=\"".&ZTOOLKIT::encode($TLCPARAM{$k})."\" "; 
					}
				$new .= " />";
				}
			elsif ($arg->{key} eq 'imageurl') {
				$new = $TLCPARAM{'src'};
				}
			}
		elsif ($arg->{key} eq 'remove') {
			$self->_cwt()->remove($new || $self->lookup_value($arg->{value}))					 
			}
		elsif ($arg->{key} eq 'append') {
			$self->_cwt()->append_content($new || $self->lookup_value($arg->{value}))	;
			}
		elsif ($arg->{key} eq 'prepend') {
			$self->_cwt()->prepend_content( $new || $self->lookup_value($arg->{value}))	
			}
		elsif ($arg->{key} eq 'replace') {
			$self->_cwt()->replace( $new || $self->lookup_value($arg->{value}))					
			}
		elsif ($arg->{key} eq 'merge') {
			my $intag =  $self->lookup_value($arg->{value});
			$self->_cwt()->attr( { $intag->attrs() } );
			}
		elsif ($arg->{key} eq 'attrib') {
			$new = $self->{var}->{default};
			$self->_cwt()->attr( $self->lookup_value($arg->{value})=>$new );
			}
		}
	}


## not implemented yet
sub core_render {
	my ($self, $command) = @_;

#[3:10:42 PM] jt: var: {"string":"<h1>This is some text</h1><p>Text is grand</p>"}
#TLC:   bind $var '.string'; render --text; append --apply;
#output: &lt;h1&lt;This is some text&lt;/h1&lt;&lt;p&lt;Text is grand&lt;/p&lt;
	}


sub core_format {
	my ($self, $command) = @_;
	
	my $var = undef;
	my $result = $self->{vars}{default};

	for my $arg (@{$command->{args}}) {
		## format --prepend, --currency
		if ($arg->{'type'} eq 'variable') {
			$var = $arg->{'value'};
			$result = (defined $self->{'vars'}->{ $var }) ? $self->{vars}->{ $var } : undef;
			}
		elsif ($arg->{'type'} eq 'longopt') {
			if ($arg->{'key'} eq 'prepend') {
				if (not defined $result) { $result = ''; }
				$result = sprintf("%s%s",$self->lookup_value($arg->{value}),$result);
				}
			elsif ($arg->{'key'} eq 'append') {
				if (not defined $result) { $result = ''; }
				$result = sprintf("%s%s",$result,$self->lookup_value($arg->{value}));
				}
			elsif ($arg->{'key'} eq 'text') {
				$result = $self->lookup_value($arg->{value}) ;
				if (not defined $result) { $result = ''; }
				}
			elsif ($arg->{'key'} eq 'truncate') {
				$result = substr($result,0,int($self->lookup_value($arg->{value})));
				}
			elsif ($arg->{'key'} eq 'chop') {
				$result = substr($result,int($self->lookup_value($arg->{value})));
				}
			elsif ($arg->{'key'} eq 'currency') {
				$result = '$' . $result;
				}
			elsif ($arg->{'key'} eq 'crlf') {
				$result .= "\n";
				}
			elsif ($arg->{'key'} eq 'length') {
				$result = length( $self->lookup_value($arg->{value}) );
				}
			#elsif ($arg->{'key'} eq 'path') {	
			#	my $path = $self->lookup_value($arg->{value});	
			#	## print "PATH:$path\n";
			#	my $jpath = JSON::Path->new('$'.$path);
		 	#	$result = $jpath->value($result);
			#	}
			elsif ($arg->{'key'} eq 'arraylength') {
				if (defined $arg->{'value'}) { 
					$result = $self->lookup_value($arg->{'value'}); 
					}
				
				if (ref($result) ne 'ARRAY') { 
					$result = -1; 
					}
				else {
					$result = scalar( @{$result} );
					}
				}
			}
		else {
			die();
			}
		}	

	## print "format result: $result\n";
	if ($var) { $self->{vars}->{$var} = $result; }
	return($self->{vars}{default} = $result);
	}

## datetime --now --out='pretty' OR --now --out='mdy' OR --now --out='ymd'
sub core_datetime {
	my ($self, $command) = @_;
	

	#print Dumper($command);
	my $var = undef;
	my $result = $self->{vars}{default};

	for my $arg (@{$command->{args}}) {
		## datetime --now --out='mdy', --now --out='pretty'
		if ($arg->{'type'} eq 'variable') {
			$var = $arg->{'value'};
			$result = (defined $self->{'vars'}->{ $var }) ? $self->{vars}->{ $var } : undef;
			}
		elsif ($arg->{key} eq 'now') { 
			$result = time(); 
			}
		elsif ($arg->{key} eq 'epoch') {
			if ($arg->{value}) { $result = $self->lookup_value($arg->{'value'}); };
			$result = int($result);
			}
		elsif ($arg->{key} eq 'ts') {
			if ($arg->{value}) { $result = $self->lookup_value($arg->{'value'}); };
			## convert date here!
			$result = int($result);
			}
		elsif ($arg->{key} eq 'out') {
			my ($style) = $self->lookup_value($arg->{'value'});
			if ($style eq 'pretty') {
				$result = strftime "%B %d, %Y", localtime($result);
				}
			elsif ($style eq 'mdy') {
				$result = strftime "%m-%d-%Y", localtime($result);
				}
			elsif ($style eq 'ymd') {
				$result = strftime "%Y-%m-%d", localtime($result);
				}
			}
		}

	if ($var) { $self->{vars}->{$var} = $result; }
	$self->{vars}{default} = $result;
	return($result);
	}

## END core commands
####################################

1;
