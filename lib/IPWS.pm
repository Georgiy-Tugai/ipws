package IPWS;
use IPWS::Wiki;
use IPWS::Blog;
use Locale::Maketext;
use IPWS::I18N;
use YAML::Tiny qw(Dump);
use Mojo::Base 'Mojolicious';
our $VERSION='0.1';
our @svcs;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');
  our %defaults=(
    'db' => {
      'server' => 'SQLite:dbname=ipws.sqlite',
      'username' => '',
      'password' => ''
    },
    'lang' => 'en',
    'svcs' => {
      '/wiki' => {
        'type' => 'Wiki',
        'name' => 'IPWS Wiki',
        'id' => 'wiki'
      },
      '/blog' => {
        'type' => 'Blog',
        'name' => 'IPWS Blog',
        'id' => 'blog'
      },
      '/admin' => {
        'type' => 'Admin',
        'name' => 'IPWS',
        'id' => 'admin'
      }
    },
    'debug' => 1 # FIXME: switch debug default to 0 for release
  );
  if (!-e $self->conf_file) { #XXX: Migrate (default) config into a seperate module!
    $self->log->info("Generating default configuration file.");
    open CONF, '>:encoding(UTF-8)', $self->conf_file or die $!;
    print CONF Dump(\%defaults);
    close CONF;
    exit;
  }
  $self->plugin('YamlConfig');
  
  my $in=IPWS::I18N->get_handle($ENV{IPWS_LANG} || $self->config('lang') || 'en') || $self->die_log($self->l("Can't find a language file for [_1], perhaps try 'en'?",$self->config('lang')));
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

  my $svcs={};
  my %safe=a2h(@svcs);
  foreach (keys %{$self->config('svcs')}) {
    my $cfg=$self->config('svcs')->{$_};
    my $type=$cfg->{'type'};
    if ($safe{$type}) {
      $svcs->{$_}="IPWS::$type"->new();
      my $r2=$r->under($_);#->detour($svcs->{$_},{base => $_,id => $cfg->{'id'}});
      $svcs->{$_}->startup($r2,$self->config('svcs')->{$_}) if "IPWS::$type"->can('startup');
    }else{
      $self->die_log($self->l("Unknown service [_1] on path [_2]",$type,$_));
    }
  }
  
  $self->hook(before_routes => sub {
    my $c = shift;
    my $path=$c->req->url->path;
    my ($disp_debug)=(0);
    foreach (keys %$svcs) {
      if ($svcs->{$_}->can('before_routes') && $path=~/^$_(.*)$/) {
        if ($disp_debug) {
          $self->warn_log("Request to $path hit an extra before_routes handler ($_, first was $disp_debug)!\n");
        }
        $svcs->{$_}->before_routes($c,$1);
        return unless $self->config('debug');
        $disp_debug=$_;
      }
    }
  });

  $r->route('/')->to(cb => sub {
    $_[0]->render('inline' => 'go to <a href="/wiki">/wiki</a> or <a href="/blog">/blog</a>');
    });
}

sub a2h {map {$_,1} @_}

sub die_log {
  my ($self,$msg)=@_;
  $self->log->error($msg);
  die $msg."\n";
}

sub warn_log {
  my ($self,$msg)=@_;
  $self->log->debug($msg);
  warn $msg."\n";
}

sub moniker {'ipws'}

sub conf_file {
  my $self=shift;
  return $self->home->rel_file($self->moniker().'.yaml');
}
1;
