package IPWS::User::Watch;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_watches',
	columns => [
		userid => {type => 'int', not_null => 1},
		watchedid => {type => 'int', not_null => 1},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => 'UTC'}
	],
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		},
		watched => {
			class => 'IPWS::User',
			key_columns => {watchedid => 'id'}
		}
	]
);
