package IPWS::Group::Pref;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'group_prefs',
	columns => [
		groupid => {type => 'int', not_null => 1},
		service => {type => 'varchar', length => 255},
		service_type => {type => 'varchar', length => 255},
		name => {type => 'varchar', length => 255, not_null => 1},
		value => {type => 'varchar', length => 255, not_null => 1}
	],
	foreign_keys => [
		group => {
			class => 'IPWS::Group',
			key_columns => {groupid => 'id'}
		}
	]
);
