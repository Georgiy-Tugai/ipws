package IPWS::Service;
use Mojo::Base 'Mojolicious';
use Module::Find;
usesub IPWS::Service;

sub new {
	my ($class)=@_;
	my $self={};
	return bless $self, $class;
}

sub type {__PACKAGE__=~/^IPWS::(.*)$/}

sub startup {
}

1;
