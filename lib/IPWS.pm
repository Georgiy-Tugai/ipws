package IPWS;
use IPWS::Wiki;
use Locale::Maketext;
use IPWS::I18N;
use Mojo::Base 'Mojolicious';
our $VERSION='0.1';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');
  if (!-e $self->conf_file) { #XXX: Migrate (default) config into a seperate module!
    $self->log->info("Generating default configuration file.");
    open CONF, '>:encoding(UTF-8)', $self->conf_file or die $!;
    my $rtfm=$self->l("Read The Fucking Manual - reconfigure me!");
    print CONF <<DEFCONF
# IPWS $VERSION config file #
db:
  server: SQLite:dbname=ipws.sqlite
  username: ''
  password: ''
lang: en
rtfm: $rtfm
DEFCONF
;
    close CONF;
    exit;
  }
  $self->plugin('YamlConfig');
  
  my $in=IPWS::I18N->get_handle($ENV{IPWS_LANG} || $self->config('lang') || 'en') || $self->die_log($self->l("Can't find a language file for _1, perhaps try 'en'?",$self->config('lang')));
  $self->attr('i18n' => sub {$in});
  $self->helper(l => sub {my $s=shift;$s->app->i18n()->maketext(@_)});
  
  if ($self->config('rtfm')) { #TODO: Write The Fucking Manual
    $self->log->error($self->l('Read The Fucking Manual - reconfigure me!'));
    die "RTFM! ".$self->l('Read The Fucking Manual - reconfigure me!')."\n";
  }
  
  $self->plugin('database',{ #TODO: Early-load 'plugins' in case they need other databases, perhaps? May be important for integrating e.g. external authentication.
    databases => {
      'db' => {
        dsn => 'dbi:'.$self->config('db')->{server} || $self->die_log($self->l("You must configure a database to use IPWS!")),
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

sub die_log {
  my ($self,$msg)=@_;
  $self->log->error($msg);
  die $msg."\n";
}

sub moniker {'ipws'}

sub conf_file {
  my $self=shift;
  return $self->home->rel_file($self->moniker().'.yaml');
}
1;
