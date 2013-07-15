package IPWS;
use IPWS::Wiki;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');
  #$self->plugin('YamlConfig');

  # Router
  my $r = $self->routes;

  $r->namespaces(['IPWS']);

  $r->route('/wiki')->detour('Wiki#handler');

  $r->route('/')->to(cb => sub {
    $_[0]->render('inline' => 'go to <a href="/wiki">/wiki</a>');
    });
}

sub moniker {'ipws'}

1;
