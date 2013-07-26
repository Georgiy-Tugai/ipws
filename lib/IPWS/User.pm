package IPWS::User;
use Mojo::Base 'IPWS::DB::Object';
use IPWS::Password;

__PACKAGE__->meta->setup(
	table => 'users',
	columns => [
		id => {type => 'serial', primary_key => 1, not_null => 1},
		login => {type => 'varchar', length => 255, not_null => 1},
		password => {type => 'varchar', length => 255, not_null => 1},
		salt => {type => 'varchar', length => 255, not_null => 1},
		pwrevid => {type => 'int', not_null => 1, default => 1},
		force_change_pw => {type => 'boolean', default => 0},
		email => {type => 'varchar', length => 255},
		emailok => {type => 'boolean', default => 0},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => "UTC"},
		ltime => {type => 'timestamp', time_zone => "UTC"},
		laddr => {type => 'char', length => 45},
		name => {type => 'varchar', length => 255},
		locale => {type => 'varchar', length => 32}
	],
	allow_inline_column_values => 1,
	unique_key => 'login',
	foreign_keys => [
		pwrev => {
			class => 'IPWS::Password::Revision',
			key_columns => {pwrevid => 'id'}
		}
	],
	relationships => [
		groups => {
			type => 'many to many',
			map_class => 'IPWS::Map::UserGroup'
		},
		prefs => {
			type => 'one to many',
			class => 'IPWS::User::Pref',
			key_columns => {id => 'userid'}
		},
		perms => {
			type => 'one to many',
			class => 'IPWS::User::Perm',
			key_columns => {id => 'userid'}
		},
		blocks => {
			type => 'one to many',
			class => 'IPWS::User::Block',
			key_columns => {id => 'userid'}
		},
		blocked_by => {
			type => 'one to many',
			class => 'IPWS::User::Block',
			key_columns => {id => 'blockedid'}
		},
		watches => {
			type => 'one to many',
			class => 'IPWS::User::Watch',
			key_columns => {id => 'userid'}
		},
		watched_by => {
			type => 'one to many',
			class => 'IPWS::User::Watch',
			key_columns => {id => 'watchedid'}
		}
	]
);

package IPWS::User::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User' }
 
__PACKAGE__->make_manager_methods('users');
1;
