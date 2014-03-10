package Pegex::Tree::DataTLC;

use strict;
use warnings;
use base 'Pegex::Tree';
our $VERSION = '1.00';

sub got_if_statement {
  my ($self, $list) = @_;
  {type => "IF", When => $list->[0], IsTrue => $list->[1], IsFalse => $list->[2] ? $list->[2][0] : undef }; 
}

sub got_while_statement {
  my ($self, $list) = @_;
  {type => "WHILE", When => $list->[0], Loop => $list->[1] }; 
}

sub got_foreach_statement {
  my ($self, $list) = @_;
  {type => "FOREACH", Set => $list->[0], Members => $list->[1], Loop => $list->[2] }; 
}

sub got_block {
  my ($self, $list) = @_;
  {type => "Block", statements => $list->[0] }; 
}

sub got_bind_statement {
  my ($self, $list) = @_;
  {type => "BIND", Set => $list->[0], Src => $list->[1]}; 
}

sub got_set_statement {
  my ($self, $list) = @_;
  {type => "SET", Set => $list->[0], Src => $list->[1], args => $list->[2]}; 
}

sub got_command {
  my ($self, $list) = @_;
  {type => 'command', module => lc($list->[0][1] || 'core'), name => lc $list->[0][2], args => $list->[1]};
}

sub got_longopt {
  my ($self, $list) = @_;
  ref $list eq 'ARRAY' ?
  {type => 'longopt', key => $list->[0], value => $list->[1]} :
  {type => 'longopt', key => $list, value => undef};
}

sub got_variable {
  my ($self, $list) = @_;
  {type => 'variable', value => $list};
}

sub got_integer {
  my ($self, $list) = @_;
  {type => 'integer', value => $list};
}

sub got_scalar {
  my ($self, $list) = @_;
  {type => 'scalar', value => $list};
}

sub got_boolean {
  my ($self, $list) = @_;
  {type => 'boolean', value => $list};
}

sub got_tag {
  my ($self, $list) = @_;
  {type => 'tag', value => $list, jq => undef};
}

sub got_hexcolor {
  my ($self, $list) = @_;
  {type => 'hexcolor', value => $list};
}

1;
