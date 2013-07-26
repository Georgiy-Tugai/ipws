package IPWS::User::Block;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_blocks',
	columns => [
		userid => {type => 'int', not_null => 1},
		blockedid => {type => 'int', not_null => 1},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp'}
	],
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		},
		blocked => {
			class => 'IPWS::User',
			key_columns => {blockedid => 'id'}
		}
	]
);
