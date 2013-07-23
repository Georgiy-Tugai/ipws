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
		}
	]
);
