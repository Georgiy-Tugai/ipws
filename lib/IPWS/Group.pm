package IPWS::Group;
use Mojo::Base 'IPWS::DB::Object';
use Carp;
use IPWS::Util qw(serv_query sort_perms);

__PACKAGE__->meta->setup(
	table => 'groups',
	columns => [
		id => {type => 'serial', primary_key => 1, not_null => 1},
		name => {type => 'varchar', not_null => 1},
		parentid => {type => 'int'}
	],
	unique_key => 'name',
	foreign_keys => [
		parent => {
			class => 'IPWS::Group',
			key_columns => {parentid => 'id'}
		}
	],
	relationships => [
		users => {
			type => 'many to many',
			map_class => 'IPWS::Map::UserGroup'
		},
		perms => {
			type => 'one to many',
			class => 'IPWS::Group::Perm',
			key_columns => {id => 'groupid'}
		},
		prefs => {
			type => 'one to many',
			class => 'IPWS::Group::Pref',
			key_columns => {id => 'groupid'}
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
		push @query, 'or', (join '.', @node[0..$_-1], '*');
	}
	#shift @query; # remove the first 'or'
	my @serv_query=serv_query($service);
	return $self->recurse_group(sub {
		my $g_perms=$_->find_perms([@serv_query, name => \@query]);
		foreach (sort_perms($g_perms)) {
			return $_->value;
		}
		return undef;
	});
}

sub recurse_group {
	my ($self,$cb)=@_;
	my $ret;
	for ($self) {$ret=$cb->($self);};
	return $ret if defined $ret;
	my $parent=$self->parent();
	return $parent->recurse_group($cb) if $parent;
	return undef;
}

package IPWS::Group::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::Group' }
 
__PACKAGE__->make_manager_methods('groups');
1;
