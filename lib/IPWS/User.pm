package IPWS::User;
use Mojo::Base 'IPWS::DB::Object';
use IPWS::Password;

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
	my @query;
	foreach (0..scalar(@node)-1) {
		push @query, 'or', (join '.', @node[0..$_]), 'or', (join '.', @node[0..$_-1], '*');
	}
	shift @query; # remove the first 'or'
	my $u_perms=IPWS::User::Perm::Manager->get_perms(
		query => [
			userid => $self->id,
			service => $service,
			name => \@query
		]
	);
	foreach (sort {length $b->name <=> length $a->name} @$u_perms) {
		return $_->value;
	}
	foreach (@{$self->groups()},IPWS::Group->new(id => 0)->load) {
		my $r=$self->can_recurse_group($service,\@query,$_);
		return $r if defined $r;
	}
}

sub _sort_perms {
	my @a_dots=split /\./, $a->name;
	my @b_dots=split /\./, $b->name;
	return $#b_dots <=> $#a_dots if $#a_dots ne $#b_dots;
	return 1 if $a_dots[-1] eq '*';
	return -1 if $b_dots[-1] eq '*';
	return 0;
}

sub can_recurse_group {
	my ($self,$service,$query,$group)=@_;
	my $g_perms=IPWS::Group::Perm::Manager->get_perms(
		query => [
			groupid => $group->id,
			service => $service,
			name => $query
		]
	);
	print STDERR join ",", map {$_->name} sort _sort_perms @$g_perms;
	print STDERR "\n";
	foreach (sort _sort_perms @$g_perms) {
		print STDERR "\t".$_->name."\n";
		return $_->value;
	}
	my $parent=$group->parent;
	if ($parent) {
		return $self->can_recurse_group($service,$query,$parent);
	}
	return undef;
}

package IPWS::User::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User' }
 
__PACKAGE__->make_manager_methods('users');
1;
