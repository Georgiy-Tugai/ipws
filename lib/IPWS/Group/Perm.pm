package IPWS::Group::Perm;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'group_perms',
	columns => [
		groupid => {type => 'int', not_null => 1},
		service => {type => 'varchar', length => 255},
		name => {type => 'varchar', length => 255, not_null => 1},
		value => {type => 'boolean', default => 1}
	],
	foreign_keys => [
		group => {
			class => 'IPWS::Group',
			key_columns => {groupid => 'id'}
		}
	]
);
