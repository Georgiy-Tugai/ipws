package IPWS::User::Session;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_sessions',
	columns => [
		id => {type => 'int', primary_key => 1},
		userid => {type => 'int'},
		salt => {type => 'varchar', length => 255, not_null => 1},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => "UTC"},
		etime => {type => 'timestamp', not_null => 1, time_zone => "UTC"},
		addr => {type => 'char', length => 45}
	],
	allow_inline_column_values => 1,
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		}
	]
);

package IPWS::User::Session::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User::Session' }
 
__PACKAGE__->make_manager_methods('sessions');
1;
