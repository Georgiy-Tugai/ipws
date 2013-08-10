package IPWS::User::Perm;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'user_perms',
	columns => [
		userid => {type => 'int', not_null => 1},
		service => {type => 'varchar', length => 255},
		service_type => {type => 'varchar', length => 255},
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

package IPWS::User::Perm::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::User::Perm' }
 
__PACKAGE__->make_manager_methods('perms');
1;
