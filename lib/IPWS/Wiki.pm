package IPWS::Wiki;
use Mojo::Base 'Mojo';
use curry;
use Data::Dumper;
push @IPWS::svcs, 'Wiki';
#sub new {
#	my ($class)=@_;
#	return bless {}, $class;
#}

sub startup {
	my ($self,$r,$cfg)=@_;
	$r->route('/')->to(cb => $self->curry::handler);
}

sub handler {
	my ($self, $c) = @_;
	my $name = $c->param('name') || 'user';
	$c->render(text => "Hello $name, welcome to what will be the IPWS Wiki!");
}

1;
