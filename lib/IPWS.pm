package IPWS;
use Locale::Maketext;
use IPWS::I18N;
use SQL::SplitStatement;
use YAML::Tiny qw(Dump LoadFile);
use Mojo::Base 'Mojolicious';
use IPWS::DB;
use Try::Tiny;
use File::Path qw(make_path);
use File::Spec::Functions qw(rel2abs abs2rel file_name_is_absolute catfile);
use Storable qw(lock_nstore lock_retrieve);
use Crypt::Digest qw(digest_data digest_data_hex digest_data_b64);
use IPWS::Service;

our $VERSION='0.1';
our @svcs;
our @res_path=qw(/ /admin);
our @res_id=qw(admin core *);
our $cfg_ver='0.1.2';
our $db;

our $die_color=1; # FIXME: Switch $die_color to 0 for release?
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
  'base' => '/',
  'static_base' => '/',
  'title' => 'IPWS',
  'svcs' => {
    'wiki' => {
      'type' => 'Wiki',
      'name' => 'IPWS Wiki',
      'shortname' => 'Wiki',
      'path' => '/wiki'
    },
    'blog' => {
      'type' => 'Blog',
      'name' => 'IPWS Blog',
      'shortname' => 'Blog',
      'path' => '/blog'
    }
  },
  'sec' => {
    'hash' => 'SHA512',
    'salt_size' => 64
  },
  'log' => {
    'level' => 'debug',
    'color' => 1, # FIXME: switch color default to 0 for release!
    'to_file' => 1,
    'path' => 'log/'
  },
  'debug' => 1 # FIXME: switch debug default to 0 for release
);

# This method will run once at server start
sub startup {
  my $self = shift;
  
  $self->{_ipws}={};
  $self->helper('ipws' => sub {$self->{_ipws}});
  
  $self->secret('Never use the builtin cookie system, it uses SHA1-HMAC. NOT PARANOID ENOUGH!'); # Make sure to actually follow this instruction :p
  
  # I18N stage 1
  my $in=IPWS::I18N->get_handle($ENV{IPWS_LANG} || 'en') || $self->die_log(sprintf("Can't find a language file for %s, perhaps try 'en'?",$ENV{IPWS_LANG}));
  $self->helper(i18n => sub {$in});
  $self->helper(l => sub {my $s=shift;$s->i18n->maketext(@_)});
  
  my $_conf_gen_error;
  if (!-e $self->conf_file) { #XXX: Migrate (default) config into a seperate module!
    $self->warn_log($self->l("Generating default configuration file."));
    try {
      open CONF, '>:encoding(UTF-8)', $self->conf_file or die "$!.\n";
      print CONF Dump(\%cfg_defaults);
      close CONF;
      exit; # FIXME: Should we exit after generating default config? Might be confusing in some cases.
    } catch {
      chomp;
      $_conf_gen_error=$_;
    }
  }
  
  #This little rigmarole is needed since the config loading process itself logs a [debug] message.
  #Make sure to switch debug=0 and log->level to info or above in defaults for release!
  
  $self->log->path('');
  $self->log->level($cfg_defaults{'log'}->{'level'}) unless $cfg_defaults{'debug'};
  $self->plugin('YamlConfig',
    default => \%cfg_defaults
  ); # Config is now loaded
  $self->{log}=Mojo::Log->new;
  $self->log->level('debug');
  $self->log->level($self->config('log')->{level}) unless $self->config('debug');
  {
    my $log_path=rel2abs($self->config('log')->{path},$self->home);
    my $log_file=catfile($log_path,$self->mode.'.log');
    try {
      make_path($log_path);
    } catch {
      chomp;
      s/ at .*?\.pm line \d+\.//;
      $self->warn_log($self->fs_fail($self->l("Can't create log folder: [_1].",$_),$log_path,
        dir => 1
      ));
    } or do {
      if ((-e $log_file && -w $log_file) || -w $log_path) {
        $self->log->path($log_file);
      } else {
        $self->warn_log($self->fs_fail($self->l("Can't create/write log file."),$log_file));
      }
    }
  }
  $die_color=$self->config('log')->{color};
  
  $self->warn_log($self->fs_fail($self->l("Could not save default configuration file: [_1]".$_conf_gen_error),$self->conf_file)) if $_conf_gen_error;
  
  # I18N stage 2
  $in=IPWS::I18N->get_handle($ENV{IPWS_LANG} || $self->config('lang') || 'en') || $self->die_log($self->l("Can't find a language file for [_1], perhaps try 'en'?",$self->config('lang')));
  delete $self->{renderer}->{helpers}->{i18n};
  $self->helper(i18n => sub {$in});
  
  # Config version check
  if (!$self->config('config_version') || $self->config('config_version') lt $cfg_ver) { #old config!
    $self->die_log($self->l("Configuration file is outdated (version=[_1]) -- there may have been incompatible changes to the schema. PLEASE CHECK THE DOCUMENTATION and then change config_version to [_2]. We'll implement automatic configuration upgrading sometime.",$self->config('config_version'),$cfg_ver));
  }
  if ($self->config('config_version') gt $cfg_ver) {
    $self->warn_log($self->l("Configuration file is from the future (version=[_1]) -- there may have been incompatible changes to the schema. PLEASE CHECK THE DOCUMENTATION and then change config_version to [_2]. Automatic configuration downgrading will never be implemented. Caveat emptor!",$self->config('config_version'),$cfg_ver));
  }
  # Config RTFM check, may be removed later
  if ($self->config('rtfm')) { #TODO: Write The Fucking Manual
    $self->log->error($self->l('Read The Fucking Manual - reconfigure me!'));
    die "RTFM! ".$self->l('Read The Fucking Manual - reconfigure me!')."\n";
  }
  
  # Database fun begins here
  IPWS::DB->startup($self);
  my $rose_dbh=IPWS::DB->new('main');
  $self->helper('db' => sub {$rose_dbh->dbh});

  $self->init_database();

  # Password REVs
  require IPWS::Password;
  IPWS::Password->latest_rev($self);
  
  # Default group
  require IPWS::Group;
  my $def_grp=IPWS::Group->new(id => 0, name => "default");
  unless ($def_grp->load(speculative => 1)) {
    $self->warn_log("Default group (name=default, id=0) not found, creating...");
    $def_grp->add_perms([
      {name => "login",
       service => '*'},
      {name => "login",
       service => 'admin',
       value => 0}
    ]);
    $def_grp->save;
  }
  
  # Default user
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
      name => 'on-password-change',
      value => 'delete-password-file',
      service => '*'
    });
    $adm_user->add_perms([
      {name => "login",
       service => '*',
       value => 1}
    ]);
    open(my $pwfil, '>:encoding(UTF-8)', $self->home->rel_file('root-password.txt')) or
      $self->die_log(fs_fail($self->l("Can't save root password! ([_1])",$@),'root-password.txt'));
    print $pwfil "$pw\n";
    close $pwfil;
    $adm_user->save;
    $self->warn_log($self->l("The password for your new 'root' account is in '[_1]'",$self->app->home->rel_file('root-password.txt')));
    $ENV{HARNESS_ACTIVE}=1; # Don't spew help
  }
  
  # Static files
  $self->helper(url_static => sub {
    my ($c,$url)=@_;
    my $u=Mojo::URL->new($self->config('static_base'));
    push @{$u->path->parts}, @{Mojo::URL->new($url)->path->parts};
    return $u;
  });
  
  $self->helper(url_static_db => sub {
    my ($c,$url)=@_;
    $url=~/^(.*)(\.[^.]+)$/;
    $c->app->url_static($1.($c->param('debug') ? '' : '.min').$2);
  });
  
  # Other helpers
  
  $self->helper(lorem => sub {
    my ($c,$rept)=@_;
    return "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." x ($rept // 1);
  });
  
  # Router
  my $_r = $self->routes;
  
  my $r=$_r;
  if ($self->config('base') ne '/') {
    $r=$_r->bridge($self->config('base'));
  }

  $self->helper(baseroutes => sub {$r});

  $_r->namespaces(['IPWS']);
  
  # Services
  $self->ipws()->{svcs}={};
  $self->attr('svcs' => sub {$_[0]->ipws()->{svcs}->{$_[1]}});
  foreach (sort {&sort_routes} keys %{$self->config('svcs')}) {
    try {
      $self->load_svc($_);
    } catch {
      $self->warn_log($_);
    }
  }
  
  $r->any('/template/:name' => sub {
    $_[0]->render($_[0]->stash('name'));
  });
  
  $r->route('/')->to(cb => sub {
    $_[0]->render('test', component => $_[0]->param('comp') || 'Admin', leftpanel => $_[0]->url_static('foundation'));
    }, path => '/');

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
  $self->hook(around_action => sub {
    my ($next,$c,$action,$last)=@_;
    my $path=$c->req->url->path;
    my $base=$c->app->config('base');
    return $next->() unless $path=~/^$base/;
    foreach (keys %{$self->ipws()->{svcs}}) {
      my %cfg=%{$self->config('svcs')->{$_}};
      if ($path=~/^$base$cfg{path}(.*)$/) {
        $c->stash()->{path}=$1;
        return $next->();
      }
    }
    $path=~/^$base(.*)$/;
    $c->stash()->{path}=$1;
    return $next->();
  });
}

sub load_svc {
  my ($self,$id)=@_;
  my %safe=a2h(@svcs);
  my %resr_p=a2h(@res_path);
  my %resr_i=a2h(@res_id);
  my $cfg=$self->config('svcs')->{$id};
  my $type=$cfg->{'type'};
  if (!$$cfg{'path'}) {
    die($self->l("Service of type [_1] (id=[_2]) does not have a path. Service disabled.",$type,$id)."\n");
  }
  if ($resr_p{$$cfg{path}}) {
    die($self->l("Service [_1] ([_2]) is on a reserved path '[_3]'. Service disabled.",$id,$type,$$cfg{path})."\n");
  }
  if ($resr_i{$id}) {
    die($self->l("Service [_1] ([_2]) has a reserved ID. Service disabled.",$id,$type)."\n");
  }
  if ($safe{$type}) { # Actually load the service
    try {
      $self->log->debug("Loading service $id...");
      $self->ipws()->{svcs}->{$id}="IPWS::Service::$type"->new(id => $id);
      $self->log->debug("Routing service $id...");
      my $r2=$self->baseroutes->under($$cfg{path});#->detour($svcs->{$id},{base => $id,id => $cfg->{'id'}});
      $self->log->debug("Starting service $id...");
      $self->ipws()->{svcs}->{$id}->startup($r2,$cfg);
      $self->log->debug("Service $id ready.");
    } catch {
      die $self->config('debug') ? "Error while loading service '$id': $_" : "Internal error while loading service!\n";
      $self->log->error($_);
    }
  }else{
    die($self->l("Unknown service [_1] (id=[_2])",$type,$id)."\n");
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
  $self->log->fatal($msg) unless $self->log->handle() eq \*STDERR;
  if ($self->log->is_fatal) {
    if ($die_color) {
      require Term::ANSIColor;
      $msg=Term::ANSIColor::colored($msg,'bold red');
    }
    die $self->log->format(fatal => $msg);
  }
}

sub warn_log {
  my ($self,$msg)=@_;
  $self->log->info($msg) unless $self->log->handle() eq \*STDERR;
  if ($self->log->is_info) {
    if ($die_color) {
      require Term::ANSIColor;
      $msg=Term::ANSIColor::colored($msg,'bold yellow');
    }
    warn $self->log->format(info => $msg);
  }
}

sub fs_fail {
  my ($self,$msg,$file,%opts)=@_;
  my ($user,$group,$groupextra);
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
      require POSIX;
      #($user,$group)=(getpwuid($>), getgrgid($))); # yes, I want effective user/group.
      $user=getpwuid($>);
      my @groups=map {(getgrgid($_))[0]} POSIX::getgroups();
      $group=shift @groups;
      $groupextra=' ('.$self->l("or any of: [_1]",join(",",@groups)).')' if @groups;
    } catch {
      $self->warn_log("For whatever reason, your non-MSWin32 operating system ($^O) does not support getpwuid and/or getgrgid and/or POSIX. The error provided by Perl is '$_'. Please report this to your system administrator, the packager for your Perl distribution, and the IPWS developers.");
    }
  }
  
  my $path=abs2rel(rel2abs($file),$self->home);
  my $ret;
  if ($opts{dir}) {
    $opts{suffix}=", ".$self->l("or create the folder yourself").($opts{suffix} || '') unless -e $path or $opts{no_creat};
    $ret=($msg." ".
      $self->l("To solve this issue, please grant read, write and execute permissions to user '[_1]' and/or group '[_2]'[_3] on the folder '[_4]'",
        $user,$group,$groupextra,$path
      ).$opts{suffix}
    );
  } else {
    $opts{suffix}=", ".$self->l("or it's containing folder").($opts{suffix} || '') unless -e $path or $opts{no_cont};
    $ret=($msg." ".
      $self->l("To solve this issue, please grant read and write permissions to user '[_1]' and/or group '[_2]'[_3] on the file '[_4]'",
        $user,$group,$groupextra,$path
      ).$opts{suffix}
    );
  }
  return $ret if defined wantarray; # die_log if called in void context
  $self->die_log($ret);
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
  state $sql_cache=-e $self->home->rel_file('sql-split-cache.db') ? lock_retrieve($self->home->rel_file('sql-split-cache.db')) : {};
  my $f;
  try {
    $f=$name.'.'.lc($self->db->{Driver}->{Name}).'.sql';
  } catch {
    chomp;
    $self->die_log($self->l("Can't initialize database object: '[_1]'",$_));
  };
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
  my $msh;
  
  # This horrible kludge is needed to solve an issue with 'bare' warnings from DBI getting into STDERR.  
  my $rethrow;
  eval {
    local $SIG{__WARN__}=sub{
      $rethrow=join(' ',@_);
      chomp $rethrow;
    };
    my $dbh=$self->db;
    #$msh=DBIx::MultiStatementDo->new(dbh => $dbh);
    #$msh->do($slurp);
    my $fdig=digest_data('SHA256',$slurp);
    if (exists $sql_cache->{$f} && $fdig eq $sql_cache->{$f}->{digest}) {
      $dbh->do($_) foreach @{$sql_cache->{$f}->{cache}};
    }else{
      my $obj=SQL::SplitStatement->new();
      my @split=$obj->split($slurp);
      $dbh->do($_) foreach @split;
      $sql_cache->{$f}={
        cache => \@split,
        digest => $fdig
      };
      lock_nstore($sql_cache,$self->home->rel_file('sql-split-cache.db'));
    }
  };
  $self->die_log($self->l("Error while executing [_1]: '[_2]'",$f,$self->db->errstr || $rethrow || $@)) if $rethrow || $@;
  # End horrible kludge
}

1;
