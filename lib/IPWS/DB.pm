package IPWS::DB;
use Mojo::Base 'Rose::DB';
__PACKAGE__->use_private_registry;
 
# Set the default domain and type
sub startup {
	my ($class,$app)=@_;
	__PACKAGE__->default_domain('development'); # $app->config('')->{...}, later
	__PACKAGE__->default_type('main');
	__PACKAGE__->register_db(
		domain   => 'development',
		type     => 'main',
		driver   => $app->config('db')->{driver},
		database => $app->config('db')->{database},
		host     => $app->config('db')->{host},
		port     => $app->config('db')->{port},
		username => $app->config('db')->{username},
		password => $app->config('db')->{password},
	);
}
