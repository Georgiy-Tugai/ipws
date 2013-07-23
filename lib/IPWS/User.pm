package IPWS::User;
use Mojo::Base 'IPWS::DBObj';

sub new {
	my ($class,$app,$id)=@_;
	my $self=$class->SUPER::new(@_);
	$self->{_can}||={};
}

sub find {
	my ($self,%attr)=@_;
	if ($attr{login}) {
		my $sth=$self->prep('SELECT id FROM '.$self->ptable.' WHERE login=?',method => 'new');
		$sth->execute($attr{login});
		my $h=$sth->fetchrow_hashref();
		return undef if not $h;
		$self->{id}=$$h{id};
		$self->refresh;
		return $self;
	}
	return undef;
}

sub refresh {
	my ($self)=@_;
	$self->SUPER::refresh();
}

sub table {'users'}

sub can {
	my ($self,$service,$node)=@_;
	$self->check();
	if (!$self->{_groups}) {
		my $sth=$self->prep('SELECT groupid FROM '.$self->ptable.'_groups WHERE userid=?',method => 'can');
		$self->{_groups}=[map {$_->[0]} @{$sth->fetchall_arrayref()}]; #only one column, anyway
	}
	my $ch=$self->{_can}->{$service}; # reduce the number of ref lookups
	if (defined $ch->{$node}) {return $ch->{$node}}
	my $sth1=$self->prep('SELECT userid FROM user_perms WHERE userid=? AND COALESCE(service,"")=? AND name=?',method => 'can');
	$sth1->execute($self->{id},$service || "",$node);
	if (scalar(@{$sth1->fetchall_arrayref()})) { # If any rows exist, user can do this.
		$ch->{
	}
}

sub clearcaches {
	my ($self)=@_;
	delete $self->{_groups};
	$self->{_can}={};
}
