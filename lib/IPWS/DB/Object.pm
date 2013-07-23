package IPWS::DB::Object;
use IPWS::DB;
use Mojo::Base qw(Rose::DB::Object);
 
sub init_db { IPWS::DB->new_or_cached('main') };
1;
