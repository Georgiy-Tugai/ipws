package IPWS::User::Pref;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_prefs',
	columns => [
		userid => {type => 'int', not_null => 1},
		service => {type => 'varchar', length => 255},
		service_type => {type => 'varchar', length => 255},
		name => {type => 'varchar', length => 255, not_null => 1},
		value => {type => 'varchar', length => 255, not_null => 1}
	],
	pk_columns => [qw(userid service service_type name)],
	foreign_keys => [
		user => {
			class => 'IPWS::User',
			key_columns => {userid => 'id'}
		}
	]
);

package IPWS::User::Pref::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User::Pref' }
 
__PACKAGE__->make_manager_methods('prefs');
1;
