package IPWS::Service;
use Mojo::Base 'Mojolicious';
use Module::Find;
use IPWS::Util qw(serv_query);
use Scalar::Util qw(weaken);
usesub IPWS::Service;

sub new {
	my ($class,%opts)=@_;
	my $self={
		id => $opts{id}
	};
	weaken($self->{app}=$opts{app});
	return bless $self, $class;
}

sub type {__PACKAGE__=~/^IPWS::(.*)$/}

sub startup {
}

sub id {$_[0]->{id}}

sub isVisible {
	my ($self,$c)=@_;
	if ($c->session->{user}) {
		return $c->session->{user}->can_do($self,'login');
	}else {
		return IPWS::Group->new(id => 0)->load()->can_do($self,'login');
	}
}

sub path {
	$_[0]->{app}->config('svcs')->{$_[0]->id()}->{path}
}

sub name {
	$_[0]->{app}->config('svcs')->{$_[0]->id()}->{name} || $_[0]->type();
}

sub shortname {
	$_[0]->{app}->config('svcs')->{$_[0]->id()}->{shortname} || $_[0]->name();
}

1;
