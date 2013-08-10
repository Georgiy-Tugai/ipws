package IPWS::Group;
use Mojo::Base 'IPWS::DB::Object';

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

package IPWS::Group::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::Group' }
 
__PACKAGE__->make_manager_methods('groups');
1;
