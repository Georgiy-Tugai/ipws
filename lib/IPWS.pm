package IPWS;
use IPWS::Wiki;
use Mojo::Base 'Mojolicious';
our $VERSION='0.1';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');
  if (!-e $self->conf_file) { #XXX: Migrate (default) config into a seperate module!
    $self->log->info("Generating default configuration file.");
    open CONF, '>', $self->conf_file or die $!;
    print CONF <<DEFCONF
# IPWS $VERSION config file #
db:
  server: SQLite:dbname=ipws.sqlite
  username: ''
  password: ''
rtfm: Read The Fucking Manual, configure IPWS before running it!
DEFCONF
;
    close CONF;
    exit;
  }
  $self->plugin('YamlConfig');
  if ($self->config('rtfm')) { #TODO: Write The Fucking Manual
    $self->log->error("RTFM! ".$self->config('rtfm'));
    die "RTFM!\n";
  }
  $self->plugin('database',{ #TODO: Early-load 'plugins' in case they need other databases, perhaps? May be important for integrating e.g. external authentication.
    databases => {
      'db' => {
        dsn => 'dbi:'.$self->config('db')->{server} || die "You must configure a database to use IPWS!\n",
        username => $self->config('db')->{username} || '',
        password => $self->config('db')->{password} || ''
      }
    }
  });

  # Router
  my $r = $self->routes;

  $r->namespaces(['IPWS']);

  #$r->route('/wiki')->detour('Wiki#handler');
  $r->route('/wiki')->detour(new IPWS::Wiki());

  $r->route('/')->to(cb => sub {
    $_[0]->render('inline' => 'go to <a href="/wiki">/wiki</a>');
    });
}

sub moniker {'ipws'}

sub conf_file {
  my $self=shift;
  return $self->home->rel_file($self->moniker().'.yaml');
}
1;
