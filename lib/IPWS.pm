package IPWS;
use Locale::Maketext;
use IPWS::I18N;
use DBIx::MultiStatementDo;
use YAML::Tiny qw(Dump LoadFile);
use Mojo::Base 'Mojolicious';
use IPWS::DB;
use Try::Tiny;

use IPWS::Wiki;
use IPWS::Blog;
our $VERSION='0.1';
our @svcs;
our @res_path=qw(/ /admin);
our @res_id=qw(admin core);
our $cfg_ver='0.1.2';
our $db;

our %cfg_defaults=(
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
  'log' => {
    'level' => 'debug'
  },
  'debug' => 1 # FIXME: switch debug default to 0 for release
);

# This method will run once at server start
sub startup {
  my $self = shift;
  
  $self->{_ipws}={};
  $self->attr('ipws' => sub {$_[0]->{_ipws}});
 
  if (!-e $self->conf_file) { #XXX: Migrate (default) config into a seperate module!
    $self->log->info("Generating default configuration file.");
    open CONF, '>:encoding(UTF-8)', $self->conf_file or die $!;
    print CONF Dump(\%cfg_defaults);
    close CONF;
    exit;
  }
  
  #This little rigmarole is needed since the config loading process itself logs a [debug] message.
  #Make sure to switch debug=0 and log->level to info or above in defaults for release!
  
  $self->log->level($defaults->{'log'}->{'level'}) unless $defaults->{'debug'};
  
  $self->plugin('YamlConfig',
    default => \%cfg_defaults
  );
  
  $self->log->level('debug');
  
  $self->log->level($self->config('log')->{level}) unless $self->config('debug');
  
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
    $self->warn_log($self->l("Admin account (login=root, id=0) not found, creating..."));
    require Text::Password::Pronounceable;
    my $pw=Text::Password::Pronounceable->generate(8,12);
    IPWS::Password->create($adm_user,$pw);
    $adm_user->force_change_pw(1);
    $adm_user->locale($self->i18n->language_tag);
    $adm_user->add_prefs({
      service => 'admin',
      name => 'on-change-password',
      value => 'delete-password-file'
    });
    open(my $pwfil, '>:encoding(UTF-8)', 'root-password.txt') or
      $self->fs_fail($self->l("Can't save root password! ([_1])",$@),'root-password.txt');
    print $pwfil "$pw\n";
    close $pwfil;
    $adm_user->save;
    $self->warn_log($self->l("The password for your new 'root' account is in '[_1]'",$self->app->home->rel_file('root-password.txt')));
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
  my %resr_p=a2h(@res_path);
  my %resr_i=a2h(@res_id);
  foreach (sort {&sort_routes} keys %{$self->config('svcs')}) {
    my $cfg=$self->config('svcs')->{$_};
    my $type=$cfg->{'type'};
    if (!$$cfg{'path'}) {
      $self->warn_log($self->l("Service of type [_1] (id=[_2]) does not have a path. Service disabled.",$type,$_));
      next;
    }
    if ($resr_p{$$cfg{path}}) {
      $self->warn_log($self->l("Service [_1] ([_2]) is on a reserved path '[_3]'. Service disabled.",$_,$type,$$cfg{path}));
      next;
    }
    if ($resr_i{$_}) {
      $self->warn_log($self->l("Service [_1] ([_2]) has a reserved ID. Service disabled.",$_,$type));
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
  die $self->log->format(fatal => $msg) if $self->log->is_fatal;
}

sub warn_log {
  my ($self,$msg)=@_;
  $self->log->info($msg);
  warn $self->log->format(info => $msg) if $self->log->is_info;
}

sub fs_fail {
  my ($self,$msg,$file,$is_dir)=@_;
  my ($user,$group);
  if ($^O eq 'MSWin32') {
    my $ok=try {
      require Win32;
    } catch {
      $self->warn_log("For whatever reason, your MSWin32 perl distribution does not have Win32.pm, or it failed to load for some other reason. The error provided by Perl is '$_'. Please report this to your system administrator, the packager for your Perl distribution, and the IPWS developers.");
    };
    if ($ok) {
      try {
        $user=Win32::LoginName();
      } catch {
        $self->warn_log("For whatever reason, your MSWin32 perl distribution's Win32.pm failed to figure out this server's username. The error provided by Perl is '$_'. Please report this to your system administrator, the packager for your Perl distribution, and the IPWS developers.");
      }
      $group="[N/A]";
    }
  }else{
    try {
      ($user,$group)=(getpwuid($>), getgrgid($))); # yes, I want effective user/group.
    } catch {
      $self->warn_log("For whatever reason, your non-MSWin32 operating system ($^O) does not support getpwuid and getgrgid. The error provided by Perl is '$_'. Please report this to your system administrator, the packager for your Perl distribution, and the IPWS developers.");
    }
  }
  require File::Spec::Functions;
  my $path=File::Spec::Functions::abs2rel(File::Spec::Functions::rel2abs($file),$self->home);
  if ($is_dir) {
    return ($msg." ".
      $self->l("To solve this issue, please grant read, write and execute permissions to user '[_1]' and/or group '[_2]' on the folder '[_3]'",
        $user,$group,$path
      )
    );
  } else {
    return ($msg." ".
      $self->l("To solve this issue, please grant read and write permissions to user '[_1]' and/or group '[_2]' on the file '[_3]'",
        $user,$group,$path
      )
    );
  }
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
  try {
    $msh->do($slurp);
  } catch {
    $self->die_log($self->l("Error while executing [_1]: '[_2]'",$f,$msh->dbh->errstr || $_));
  }
}

1;
