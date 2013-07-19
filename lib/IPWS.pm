package IPWS;
use IPWS::Wiki;
use IPWS::Blog;
use Locale::Maketext;
use IPWS::I18N;
use YAML::Tiny qw(Dump);
use Mojo::Base 'Mojolicious';
our $VERSION='0.1';
our @svcs;
our @res_path=qw(/ /admin);

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

  $self->init_database();

  # Router
  my $r = $self->routes;

  $r->namespaces(['IPWS']);
  
  $r->route('/')->to(cb => sub {
    $_[0]->render('test');
    });
  
  my $svcs={};
  my %safe=a2h(@svcs);
  my %resr=a2h(@res_path);
  foreach (sort {&sort_routes} keys %{$self->config('svcs')}) {
    my $cfg=$self->config('svcs')->{$_};
    my $type=$cfg->{'type'};
    if ($resr{$_}) {
      $self->warn_log($self->l("Service [_1] ([_2]) is on a reserved path '[_3]'. Service disabled.",$$cfg{id},$type,$_));
      next;
    }
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
}

sub sort_routes {
  length join "", $a=~m#/# <=> length join "", $b=~m#/#;
}

sub a2h {map {$_,1} @_}

sub die_log {
  my ($self,$msg)=@_;
  $self->log->fatal($msg);
  die $msg."\n";
}

sub warn_log {
  my ($self,$msg)=@_;
  $self->log->error($msg);
  warn $msg."\n";
}

sub moniker {'ipws'}

sub conf_file {
  my $self=shift;
  return $self->home->rel_file($self->moniker().'.yaml');
}

sub init_database {
  my $self=shift; #XXX: Move this into a seperate file, etc.
  map {$self->db()->do($_.';')} split /;/, q[
CREATE TABLE IF NOT EXISTS Users
(
ID int,
Login varchar(255),
Password char(512),
Email varchar(255),
EmailOK boolean,
CTime int,
LTime int,
Name varchar(255)
);
CREATE TABLE IF NOT EXISTS Groups
(
ID int,
Name varchar(255)
);
CREATE TABLE IF NOT EXISTS User_Groups
(
UserID int,
GroupID int
);
CREATE TABLE IF NOT EXISTS Permissions
(
ID int,
Service varchar(255),
Name varchar(255)
);
CREATE TABLE IF NOT EXISTS User_Permissions
(
UserID int,
PermID int
);
CREATE TABLE IF NOT EXISTS Group_Permissions
(
GroupID int,
PermID int
);
];
}

1;
