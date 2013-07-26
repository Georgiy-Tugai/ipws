package IPWS::User::Report;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_reports',
	columns => [
		id => {type => 'serial', primary_key => 1, not_null => 1}
		service => {type => 'varchar', length => 255},
		objectid => {type => 'int'},
		objecttype => {type => 'varchar', length => 255},
		userid => {type => 'int', not_null => 1},
		subjectid => {type => 'int'},
		rcontent => {type => 'text'},
		icontent => {type => 'text'},
		summary => {type => 'varchar', length => 255},
		response => {type => 'text'},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => "UTC"},
		name => {type => 'varchar', length => 255, not_null => 1},
		value => {type => 'varchar', length => 255, not_null => 1}
	],
	allow_inline_column_values => 1,
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		}
	]
);
