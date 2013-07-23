package IPWS::Map::UserGroup;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_groups',
	columns => [
		userid => {type => 'int', not_null => 1},
		groupid => {type => 'int', not_null => 1}
	],
	primary_key_columns => [qw(userid groupid)],
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		},
		group => {
			class => 'IPWS::Group',
			key_columns => {groupid => 'id'}
		}
	]
);
