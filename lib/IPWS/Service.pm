package IPWS::Service;
use Mojo::Base 'Mojolicious';

sub new {
	my ($class)=@_;
	my $self={};
	return bless $self, $class;
}

1;
