package IPWS::Blog;
use Mojo::Base 'Mojo';
use Data::Dumper;
push @IPWS::svcs, 'Blog';

sub startup {
	my ($self,$r)=@_;
	my $post=$r->route('/:post',post => '0');
	$post->post()->to(action => 'post');
	$post->get()->to(action => 'get');
	#$r->get('/:post')->to(post => '0',action => 'get');
	#$r->post('/:post/post')->to(action => 'post');
	#$r->delete('/delete/:post')->to(action => 'delete');
}

sub handler {
	my ($self,$c)=@_;
	$c->render(text => $self->_post($c->stash('post'))."\n".$c->stash('action'));
}

sub _post { #FIXME: stub
	my ($self,$id)=@_;
	return ($id % 2 == 0) ? "This is post number $id, lorem ipsum." : undef;
}

1;
