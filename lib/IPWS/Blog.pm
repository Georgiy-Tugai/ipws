package IPWS::Blog;
use Mojo::Base 'Mojo';
use Data::Dumper;
use feature 'switch';
use curry;
push @IPWS::svcs, 'Blog';

sub startup {
	my ($self,$r,$cfg)=@_;
	$r->get('/new')->to(cb => $self->curry::handler);
	$r->get('/ask')->to(cb => $self->curry::handler);
	$r->get('/mail')->to(cb => $self->curry::handler);
	$r->get('/admin')->to(cb => $self->curry::handler,action => 'admin');
	$r->get('/*default')->to(cb => $self->curry::drawPost,post => 0);
	$self->{cfg}=$cfg;
}

sub before_routes {
	my ($self,$c,$path)=@_;
	if ($path=~m#^\/?(?:(\d+)(?:[.-/_][^/]+)?)?$#) { #/123.blog-post-title
		$c->stash('post' => $1 || 0);
		$self->drawPost($c);
	}
}

sub drawPost {
	my ($self,$c)=@_;
	$c->render(text => $self->_post($c->stash('post')));
}

sub handler {
	my ($self,$c)=@_;
	print STDERR Dumper $c->req->method;
	$c->render(text => $c->stash('action').','.$c->stash('path'));
}

sub _post { #FIXME: stub
	my ($self,$id)=@_;
	return ($id % 2 == 0) ? "This is post number $id, lorem ipsum." : "yadda yadda yadda $id";
}

1;
