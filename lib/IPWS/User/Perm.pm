package IPWS::User::Perm;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_perms',
	columns => [
		userid => {type => 'int', not_null => 1},
		service => {type => 'varchar', length => 255},
		name => {type => 'varchar', length => 255, not_null => 1},
		value => {type => 'boolean', default => 1}
	],
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		}
	]
);
