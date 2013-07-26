package IPWS::Password::Revision;
use Mojo::Base 'IPWS::DB::Object';

__PACKAGE__->meta->setup(
	table => 'pwrevs',
	columns => [
		id => {type => 'serial', not_null => 1, primary_key => 1},
		ctime => {type => 'timestamp', not_null => 1, default => 'current_timestamp', time_zone => 'UTC'},
		libver => {type => 'varchar', length => 64, not_null => 1},
		hash => {type => 'varchar', length => 64, not_null => 1}
	],
	allow_inline_column_values => 1
);
1;

package IPWS::Password::Revision::Manager;
use Mojo::Base 'IPWS::DB::Object::Manager';

sub object_class { 'IPWS::Password::Revision' }
 
__PACKAGE__->make_manager_methods('pwrev');
1;
