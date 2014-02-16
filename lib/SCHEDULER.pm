package SCHEDULER;

sub new {
   my ($class, $USERNAME) = @_;

   my $self = {};
   bless $self, 'SCHEDULER';

   return($self);
   }


sub list {
   my ($self) = @_;
   }

sub run_at {
   my ($self, %options) = @_;
   return();
   }

sub run_every {
   my ($self, %options) = @_;
   return();
   }



1;

