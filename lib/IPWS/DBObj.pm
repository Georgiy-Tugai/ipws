package IPWS::DBObj;
use Scalar::Util qw(weaken);
use Cache::LRU;
use Carp;

has 'app' => sub {$_[0]->{'_app'}};
has 'db' => sub {$_[0]->app->db};
has 'prefix' => sub {$_[0]->app->config('db')->{'prefix'} || ''};

sub AUTOLOAD {
	my ($self)=@_;
	
}

sub new {
	my ($class,$app,$id)=@_;
	my $self={
		'_app' => undef,
		'_cache_time' => -1
	};
	weaken($self->{'_app'}=$app);
	bless $self, $class;
	if ($id) {
		$self->{id}=$attr{id};
	}
	return $self;
}

sub table {croak "No table defined for a DBObj?!\n";}
sub ptable {$_[0]->prefix.$_[0]->table}

sub prep {
	my ($self,$st,@rest)=@_;
	return $self->db->prepare_cached($st,{dummy => 'DBObj:'.ref $self,@rest});
}

sub refresh {
	my ($self)=@_;
	my $sth=$self->prep('SELECT * FROM '.$self->ptable.' WHERE id=?',method => 'refresh');
	$sth->execute($self->{id});
	my $h=$sth->fetchrow_hashref();
	foreach (keys %$h) {
		if ($_ eq 'id' && $$h{$_} != $self->{id}) { # TODO: Is this check necessary?
			$self->die_log("MAJOR DB INCONSISTENCY! WHERE id=$k RETURNED A ROW WITH A DIFFERENT ID!");
		}else{
			$self->{$_}=$$h{$_};
		}
	}
}
