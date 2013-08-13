package IPWS::Sessions;
use Mojo::Base -base;

use Crypt::Digest qw(digest_data digest_data_hex digest_data_b64);
use Crypt::Mac::HMAC qw(hmac hmac_hex hmac_b64);
use Mojo::Util qw(b64_decode b64_encode secure_compare);
use Mojo::JSON;
use Math::Random::Secure qw(irand);
use IPWS::Password;
use DateTime::Duration;
use Carp;
use Guard;

has [qw(cookie_domain secure)];
has cookie_name => 'ipws';
has cookie_path => '/';
has default_expiration => 3600;

sub load {
	my ($self, $c)=@_;
	
	#$c->app->log->debug("Loading session...");
	return unless my $value = $c->cookie($self->cookie_name);
	#$c->app->log->debug("Cookie found");
	#$c->app->log->debug($value);
	$value=~tr/-/=/;
	my ($sessid,$hash,$json)=unpack 'LL/aa*',b64_decode($value);
	my $sess;
	my $stash = $c->stash;
	my $grd = guard {
		$sess->delete if $sess;
		delete $stash->{'mojo.active_session'};
		delete $stash->{'mojo.session'};
		delete $stash->{'mojo.session.id'};
		$stash->{'mojo.session.wipe'}=1;
	};
	return unless $sess = IPWS::User::Session->new(id => $sessid)->load(speculative => 1);
	#$c->app->log->debug("User found");
	my $dur=DateTime::Duration->new(seconds => $c->app->config('sec')->{session}->{expiry});
	my $now=DateTime->now();
	if ($sess->etime() < $now) { #expired
		$sess->delete();
	}
	#$c->app->log->debug("Time OK");
	my $salt=pack('h*',$sess->salt);
	$c->app->log->debug($sess->salt);
	return unless secure_compare($hash,hmac_hex($IPWS::Password::opts{hash},$salt,$json));
	#$c->app->log->debug("Hash OK");
	return unless my $data = Mojo::JSON->new->decode($json);
	#$c->app->log->debug("JSON OK");
	
	return unless $stash->{'mojo.active_session'} = keys %$data;
	
	$c->app->warn_log("Session for ".($sess->user ? $sess->user->name() : '???')." loaded ok!");
	$data->{'user'}=$sess->user if $sess->user;
	$stash->{'mojo.session'} = $data;
	$data->{flash} = delete $data->{new_flash} if $data->{new_flash};
	$stash->{'mojo.session.id'}=$sessid;
	$grd->cancel();
}

sub cleanup {
	my ($self,$app)=@_;
	my $dur=DateTime::Duration->new(seconds => $app->config('sec')->{session}->{expiry});
	my $now=DateTime->now();
	IPWS::User::Session::Manager->delete_sessions(
		where => [
			etime => { lt => $now }
		]
	);
}

sub store {
	my ($self, $c)=@_;
	#$c->app->log->debug("Session::store called!");
	my $stash = $c->stash;
	return unless my $data = $stash->{'mojo.session'};
	#return unless keys %$data || $stash->{'mojo.active_session'};
	
	if (!$stash->{'mojo.static'}) {
		if (keys %$data) {
			#$c->app->log->debug("Session::store running!");
			delete $data->{flash};
			delete $data->{new_flash} unless keys %{$data->{new_flash}};
			
			my $json=Mojo::JSON->new->encode($data);
			my $sess;
			if (exists $stash->{'mojo.session.id'} and $sess=IPWS::User::Session->new(id => $stash->{'mojo.session.id'})->load(speculative => 1, for_update => 1)) {
			}else{
				my $loaded;
				my $attempts;
				do {
					$sess=IPWS::User::Session->new(id => irand());
				} while ($loaded=$sess->load(speculative => 1) && $attempts++ < $c->app->config('sec')->{session}->{attempts});
				$c->app->die_log("RAN OUT OF SESSION IDS! OMG!") if $loaded;
				if ($data->{'user'}) {
					$sess->user($data->{'user'});
				}else{
					#$c->app->warn_log("Creating a session without a user!");
				}
			}
			if ($data->{'user'}) {
				$sess->etime(DateTime->now() + DateTime::Duration->new(seconds => $c->app->config('sec')->{session}->{expiry}));
			}else{
				$sess->etime(DateTime->now() + DateTime::Duration->new(seconds => $c->app->config('sec')->{session}->{anon_expiry}));
			}
			my $salt=IPWS::Password::gen_salt();
			#$c->app->log->debug(unpack 'h*', $salt);
			$sess->salt(unpack('h*', $salt));
			my $hash=hmac_hex($IPWS::Password::opts{hash},$salt,$json);
			$sess->save;
			my $value=b64_encode(pack 'LL/aa*', $sess->id, $hash, $json);
			$value=~tr/\n//d;
			$value=~tr/=/-/;
			my $options = {
				domain   => $self->cookie_domain,
				expires  => time + $c->app->config('sec')->{session}->{expiry},
				httponly => 1,
				path     => $self->cookie_path,
				secure   => $self->secure
			};
			#$c->app->log->debug($value);
			$c->cookie($self->cookie_name, $value, $options);
		} elsif ($stash->{'mojo.session.wipe'}){
			$self->wipe_cookie($c);
		}
	}
}

sub wipe_cookie {
	my ($self, $c)=@_;
	if ($c->session('user')) {
		my $sess;
		$sess=IPWS::User::Session->new(id => $c->stash->{'mojo.session.id'})->load(speculative => 1) and $sess->delete();
		delete $c->session->{user};
		delete $c->stash->{'mojo.session.id'};
	}
	my $options = {
		domain   => $self->cookie_domain,
		expires  => 1,
		httponly => 1,
		path     => $self->cookie_path,
		secure   => $self->secure
	};
	$c->cookie($self->cookie_name, '', $options);
}

1;
