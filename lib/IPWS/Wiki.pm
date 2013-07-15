package IPWS::Wiki;
use Mojo::Base 'Mojo';
use Data::Dumper;
#sub new {
#	my ($class)=@_;
#	return bless {}, $class;
#}

sub handler {
	my ($self, $c) = @_;
	my $name = $c->param('name') || 'user';
	$c->render(text => "Hello $name, welcome to what will be the IPWS Wiki!");
}

1;
