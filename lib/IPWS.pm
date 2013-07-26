package IPWS;
use Locale::Maketext;
use IPWS::I18N;
use DBIx::MultiStatementDo;
use YAML::Tiny qw(Dump);
use Mojo::Base 'Mojolicious';
use IPWS::DB;

use IPWS::Wiki;
use IPWS::Blog;
our $VERSION='0.1';
our @svcs;
our @res_path=qw(/ /admin);
our $cfg_ver='0.1.2';
our $db;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');
  $self->{_ipws}={
    'installer_mode' => 0
  };
  $self->attr('ipws' => sub {$_[0]->{_ipws}});
  
  our %defaults=(
    'config_version' => $cfg_ver,
    'db' => {
      #'dsn' => 'dbi:SQLite:dbname=ipws.sqlite',
      'driver' => 'SQLite',
      'database' => 'ipws.sqlite',
      'host' => '',
      'port' => '',
      'username' => '',
      'password' => '',
      'prefix' => ''
    },
    'lang' => 'en',
    'svcs' => {
      'wiki' => {
        'type' => 'Wiki',
        'name' => 'IPWS Wiki',
        'path' => '/wiki'
      },
      'blog' => {
        'type' => 'Blog',
        'name' => 'IPWS Blog',
        'path' => '/blog'
      }
    },
    'sec' => {
      'hash' => 'SHA512',
      'salt_size' => 64
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
  
  if (!$self->config('config_version') || $self->config('config_version') lt $cfg_ver) { #old config!
    $self->die_log($self->l("Configuration file is outdated (version=[_1]) -- there may have been incompatible changes to the schema. PLEASE CHECK THE DOCUMENTATION and then change config_version to [_2]. We'll implement automatic configuration upgrading sometime.",$self->config('config_version'),$cfg_ver));
  }
  if ($self->config('config_version') gt $cfg_ver) {
    $self->warn_log($self->l("Configuration file is from the future (version=[_1]) -- there may have been incompatible changes to the schema. PLEASE CHECK THE DOCUMENTATION and then change config_version to [_2]. Automatic configuration downgrading will never be implemented. Caveat emptor!",$self->config('config_version'),$cfg_ver));
  }
  
  if ($self->config('rtfm')) { #TODO: Write The Fucking Manual
    $self->log->error($self->l('Read The Fucking Manual - reconfigure me!'));
    die "RTFM! ".$self->l('Read The Fucking Manual - reconfigure me!')."\n";
  }
  
  IPWS::DB->startup($self);
  $self->helper('db' => sub {IPWS::DB->new_or_cached('main')->dbh});

  $self->init_database();

  require IPWS::Password;
  IPWS::Password->latest_rev($self);
  
  require IPWS::Group;
  my $def_grp=IPWS::Group->new(id => 0, name => "default");
  unless ($def_grp->load(speculative => 1)) {
    $self->warn_log("Default group (name=default, id=0) not found, creating...");
    $def_grp->add_perms([
      {name => "login"}
    ]);
    $def_grp->save;
  }
  
  require IPWS::User;
  my $adm_user=IPWS::User->new(id => 0, login => "root");
  unless ($adm_user->load(speculative => 1)) {
    $self->warn_log("Admin account (login=root, id=0) not found, creating...");
    require Text::Password::Pronounceable;
    my $pw=Text::Password::Pronounceable->generate(8,12);
    $self->warn_log("ADMIN PASSWORD: $pw");
    IPWS::Password->create($adm_user,$pw);
    $adm_user->save;
  }
  
  # Router
  my $r = $self->routes;

  $r->namespaces(['IPWS']);
  
  $r->route('/')->to(cb => sub {
    $_[0]->render('test');
    });
  
  $self->ipws()->{svcs}={};
  $self->attr('svcs' => sub {$_[0]->ipws()->{svcs}->{$_[1]}});
  my %safe=a2h(@svcs);
  my %resr=a2h(@res_path);
  foreach (sort {&sort_routes} keys %{$self->config('svcs')}) {
    my $cfg=$self->config('svcs')->{$_};
    my $type=$cfg->{'type'};
    if (!$$cfg{'path'}) {
      $self->warn_log($self->l("Service of type [_1] (id=[_2]) does not have a path. Service disabled.",$type,$_));
      next;
    }
    if ($resr{$$cfg{path}}) {
      $self->warn_log($self->l("Service [_1] ([_2]) is on a reserved path '[_3]'. Service disabled.",$_,$type,$$cfg{path}));
      next;
    }
    if ($safe{$type}) {
      $self->ipws()->{svcs}->{$_}="IPWS::$type"->new();
      my $r2=$r->under($$cfg{path});#->detour($svcs->{$_},{base => $_,id => $cfg->{'id'}});
      $self->ipws()->{svcs}->{$_}->startup($r2,$cfg) if "IPWS::$type"->can('startup');
    }else{
      $self->die_log($self->l("Unknown service [_1] (id=[_2])",$type,$_));
    }
  }

  if (0) { #TODO: It seems that we might not need this after all.
    $self->hook(before_routes => sub {
      my $c = shift;
      my $path=$c->req->url->path;
      my ($disp_debug)=(0);
      foreach (keys %{$self->ipws()->{svcs}}) {
        my $cfg=%{$self->config('svcs')->{$_}};
        if ($self->svcs($_)->can('before_routes') && $path=~/^$$cfg{path}(.*)$/) {
          if ($disp_debug) {
            $self->warn_log("Request to $path hit an extra before_routes handler ($_, first was $disp_debug)!\n");
          }
          $self->svcs($_)->before_routes($c,$1);
          return unless $self->config('debug');
          $disp_debug=$_;
        }
      }
    });
  }
}

sub user {
  my ($self,%attr)=@_;
  return IPWS::User->new($self,%attr);
}

sub group {
  my ($self,%attr)=@_;
  return IPWS::Group->new($self,%attr);
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
  $self->run_sql('init');
}

sub run_sql {
  my ($self,$name)=@_;
  my $f=$name.'.'.lc($self->db->{Driver}->{Name}).'.sql';
  if (!-e $f) {
    $f=$name.'.sql';
    $self->die_log($self->l("No such sql file: [_1]",$f)) unless -e $f;
  }
  open FIL, '<:utf8', $f or $self->die_log($!);
  my $slurp;
  while (<FIL>) {
    $slurp.=$_;
  }
  close FIL;
  my $msh=DBIx::MultiStatementDo->new(dbh => $self->db);
  eval {
    $msh->do($slurp);
  };
  $self->die_log($self->l("Error while executing [_1]: '[_2]'",$f,$msh->dbh->errstr || $@)) if $@;
}

1;
