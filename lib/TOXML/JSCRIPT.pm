package TOXML::JSCRIPT;


use JavaScript;

##
## FACT1: we need something more universal than SPECL -- it takes too long to learn.
##	FACT2: specl is slow, and in general the process_list function is slow.
##


##
## 
##
sub process_list {
	my ($spec,$items,$vars,%options) = @_;

	## any alternating, or columsn, or crap like that should be handled within the list logic, NOT by process list

	# Create a runtime and a context
	my $rt = JavaScript::Runtime->new();
	my $cx = $rt->create_context();
	my $OUTPUT;

	# Add a function which we can call from JavaScript
	$cx->bind_function(print => sub { $OUTPUT .= $_[0]; });
	require TOXML::JSCRIPT::ZLIST;
	$cx->bind_class(  
		name => "ZList", 
		constructor => sub { TOXML::JSCRIPT::ZLIST->new($items); },
		package => "TOXML::JSCRIPT::ZLIST",
		# methods => { to_string => \&My::Package::to_string,  random    => "randomize" }
		methods => {
			
			},
		ps => { 
			length => [ sub { return(scalar(@{$items})+1); } , undef ],
			# parent => { getter => \&MyClass::get_parent, setter => \&MyClass::set_parent },
			}
		);

	my $result = $cx->eval($spec);
	return($OUTPUT);
	}

1;
