package IPWS::Service::Admin;
use Mojo::Base 'IPWS::Service';
use curry;
use Data::Dumper;
push @IPWS::svcs, 'Admin';

sub startup {
	my ($self,$r,$cfg)=@_;
	$r->route('/')->to(cb => $self->curry::handler);
}

sub handler {
	my ($self, $c) = @_;
	my $name = $c->session->{user} ? $c->session->{user}->name() : 'anonymous user';
	#$c->render(text => "Hello $name, welcome to what will be the IPWS Control Panel!");
	$c->render('admin');
}

sub path {
	'/admin';
}

sub name {
	$_[0]->{app}->l('Global Settings');
}
