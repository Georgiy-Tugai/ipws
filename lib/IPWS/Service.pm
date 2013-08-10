package IPWS::Service;
use Mojo::Base 'Mojolicious';
use Module::Find;
usesub IPWS::Service;

sub new {
	my ($class,%opts)=@_;
	my $self={
		id => $opts{id}
	};
	return bless $self, $class;
}

sub type {__PACKAGE__=~/^IPWS::(.*)$/}

sub startup {
}

sub id {$_[0]->{id}}

1;
