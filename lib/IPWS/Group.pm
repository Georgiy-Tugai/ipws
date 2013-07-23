package IPWS::Group;
use Mojo::Base 'IPWS::DBObj';

sub new {
	my ($class,$app,$id)=@_;
	my $self=$class->SUPER::new(@_);
	$self->{_can_cache}||={};
	$self->{_parent_cache}||={};
	if ($attr{name}){
		my $sth=$self->prep('SELECT id FROM '.$self->ptable.' WHERE name=?',method => 'new');
		$sth->execute($attr{name});
		$self->{id}=$sth->fetchrow_hashref()->{id};
		$self->refresh;
	}
}

sub table {'groups'}

sub can {
	
}
