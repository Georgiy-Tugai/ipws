package IPWS::Service::Blog;
use Mojo::Base 'IPWS::Service';
use Data::Dumper;
use feature 'switch';
use curry;
push @IPWS::svcs, 'Blog';

sub startup {
	my ($self,$r,$cfg)=@_;
	$r->get('/new')->to(cb => $self->curry::handler, action => 'new');
	$r->get('/ask')->to(cb => $self->curry::handler, action => 'ask');
	$r->get('/mail')->to(cb => $self->curry::handler, action => 'mail');
	$r->get('/admin')->to(cb => $self->curry::handler,action => 'admin');
	my $r2=$r->route('/#post',post => qr/(\d+)/)->to(cb => $self->curry::drawPost,post => 0);
	$r2->route('/')->to(cb => $self->curry::drawPost);
	$r2->route('/:suf')->to(cb => $self->curry::drawPost);
	$self->{cfg}=$cfg;
}

sub drawPost {
	my ($self,$c)=@_;
	$c->render('blog');
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
