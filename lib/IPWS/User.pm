package IPWS::User;
use Mojo::Base 'IPWS::DB::Object';
use IPWS::Password;
use Carp;
use IPWS::Util qw(serv_query sort_perms);
our @CARP_NOT=qw(IPWS::Util);

__PACKAGE__->meta->setup(
	table => 'users',
	columns => [
		id => {type => 'serial', primary_key => 1, not_null => 1},
		login => {type => 'varchar', length => 255, not_null => 1},
		password => {type => 'varchar', length => 255, not_null => 1},
		salt => {type => 'varchar', length => 255, not_null => 1},
		pwrevid => {type => 'int', not_null => 1, default => 1},
		force_change_pw => {type => 'boolean', default => 0},
		email => {type => 'varchar', length => 255},
		emailok => {type => 'boolean', default => 0},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => "UTC"},
		ltime => {type => 'timestamp', time_zone => "UTC"},
		laddr => {type => 'char', length => 45},
		name => {type => 'varchar', length => 255},
		locale => {type => 'varchar', length => 32}
	],
	allow_inline_column_values => 1,
	unique_key => 'login',
	foreign_keys => [
		pwrev => {
			class => 'IPWS::Password::Revision',
			key_columns => {pwrevid => 'id'}
		}
	],
	relationships => [
		sessions => {
			type => 'one to many',
			class => 'IPWS::User::Session',
			key_columns => {id => 'userid'}
		},
		groups => {
			type => 'many to many',
			map_class => 'IPWS::Map::UserGroup'
		},
		prefs => {
			type => 'one to many',
			class => 'IPWS::User::Pref',
			key_columns => {id => 'userid'}
		},
		perms => {
			type => 'one to many',
			class => 'IPWS::User::Perm',
			key_columns => {id => 'userid'}
		},
		blocks => {
			type => 'one to many',
			class => 'IPWS::User::Block',
			key_columns => {id => 'userid'}
		},
		blocked_by => {
			type => 'one to many',
			class => 'IPWS::User::Block',
			key_columns => {id => 'blockedid'}
		},
		watches => {
			type => 'one to many',
			class => 'IPWS::User::Watch',
			key_columns => {id => 'userid'}
		},
		watched_by => {
			type => 'one to many',
			class => 'IPWS::User::Watch',
			key_columns => {id => 'watchedid'}
		}
	]
);

sub can_do {
	my ($self,$service,@node)=@_;
	if ($node[0]=~/\./) {
		@node=split /\./, $node[0];
	}
	my @query=(join '.', @node);
	foreach (0..scalar(@node)-1) {
		#push @query, 'or', (join '.', @node[0..$_]), 'or', (join '.', @node[0..$_-1], '*');
		push @query, 'or', (join '.', @node[0..$_-1], '*');
	}
	#shift @query; # remove the first 'or'
	my @serv_query=serv_query($service);
	my $u_perms=$self->find_perms([@serv_query,name => \@query]);
	foreach (sort_perms($u_perms)) {
		return $_->value;
	}
	return $self->foreach_group(sub {
		$_->can_do($service,@node);
	});
}

sub foreach_group {
	my ($self,$cb)=@_;
	foreach (@{$self->groups()},IPWS::Group->new(id => 0)->load) {
		my $r=$cb->($_);
		return $r if defined $r;
	}
	return undef;
}

sub get_pref {
	my ($self,$service,@node)=@_;
	if (defined $service and not ref $service) {
		croak "The first parameter to get_pref must be an IPWS::Service or undef!";
	}
	my $pref;
	unless ($node[0]=~/\./) {
		$pref=join ".",@node;
	}else{
		$pref=$node[0];
	}
	my @serv_query=serv_query($service);
	return $self->find_prefs([@serv_query, name => $pref])->[0] // $self->foreach_group(sub {
		$_->find_prefs([@serv_query, name => $pref])->[0];
	});
}

package IPWS::User::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User' }
 
__PACKAGE__->make_manager_methods('users');
1;
