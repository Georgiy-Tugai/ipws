package IPWS::User;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'users',
	columns => [
		id => {type => 'serial', primary_key => 1, not_null => 1},
		login => {type => 'varchar', length => 255, not_null => 1},
		password => {type => 'char', length => 512, not_null => 1},
		email => {type => 'varchar', length => 255},
		emailok => {type => 'boolean', default => 0},
		ctime => {type => 'integer', not_null => 1},
		ltime => {type => 'integer'},
		laddr => {type => 'char', length => 45},
		name => {type => 'varchar', length => 255},
		locale => {type => 'varchar', length => 32}
	],
	unique_key => 'login',
	relationships => [
		groups => {
			type => 'many to many',
			map_class => 'IPWS::Map::UserGroup'
		}
	]
);
