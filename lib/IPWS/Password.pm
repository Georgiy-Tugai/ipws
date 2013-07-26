package IPWS::Password;
# ! READ BEFORE MODIFYING !
# This file manages end-user passwords!
#
# Don't make incompatible changes, especially to the check() function,
# unless you absolutely have to.
# When incompatible changes are made, increment $VERSION.
# Then edit the topmost if in check() to
# elsif ($rev->libver lt 'your-version-here')
# and add your hashing code to a new if block of the format shown below:
# if ($rev->libver le 'your-version-here')
# 
# If even greater changes must occur, which invalidate the aformenetioned
# compatibility structure,
# 1) Make sure to obtain community consensus as to the changes. Preferably,
#    contact the original or primary developers with an explanation of your
#    changes to this library.
# 2) Increment the global $VERSION, $cfg_ver and increment IPWS/Password.pm
#    $VERSION by a major release. (e.g 1.1.0 -> 2.0)
# 3) If possible, include a maintenance script or Mojolicious command in order
#    to provide a clean upgrade path.
# 4) Document the change in README.md, including upgrade path(s) if any.
# 5) Whoever is responsible for dissmeniation of IPWS-related security
#    advisories and/or general news should warn IPWS end-users and
#    administrators of the upcoming incompatible release IN ADVANCE.
#     Rationale: Some people update automatically without heed to Changelog.
#
# Best of luck. Hopefully such changes will not have to be frequent.
#  --- original IPWS developers (SAL9000, jakeanq)
our @hash=qw(
	RIPEMD128 RIPEMD160 RIPEMD256 RIPEMD320
	SHA224 SHA256 SHA384 SHA512
	Tiger192 Whirlpool
);
use Crypt::Mac::HMAC qw(hmac hmac_hex);
use Math::Random::Secure qw(irand);
use IPWS::Password::Revision;
use Math::Round qw(nhimult);
use List::Util qw(first);

our $VERSION='0.1';
our %opts=(
	hash => 'SHA512',
	salt_size => 128
);
our $latest_rev;

sub create {
	my ($class,$user,$password)=@_;
	my $salt=gen_salt();
	my $hash=hmac_hex($opts{hash},$salt,$password);
	$user->salt($salt);
	$user->password($hash);
	$user->pwrev($latest_rev);
	$user->save;
}

sub check {
	my ($class,$user,$password)=@_;
	my $rev=$user->pwrev;
	if ($rev->libver le '0.1') {
		my $check=hmac_hex($rev->hash,$user->salt,$password);
		return $user->password eq $check;
	}else{
		die "Unknown Password.pm revision in check() pwrev. Contact your system administrator for assistance.\n";
	}
}

# This function can be changed safely, however if security-minded changes
# are made, $VERSION should still be bumped, so that end-users are notified
# and offered an opportunity to change their password to use the stronger salt.
sub gen_salt {
	my $salt='';
	my @steps=map {256**$_} 0..4;
	foreach (1..nhimult(4,$opts{salt_size})/4) {
		my $val=irand;
		foreach (1..4) {
			my $temp=$val % $steps[$_];
			$val-=$temp;
			$salt.=chr $temp/$steps[$_-1];
		}
	}
	return $salt;
}

sub latest_rev {
	my ($class,$app)=@_;
	if (not defined first {$app->config('sec')->{hash} eq $_} @hash) {
		$app->die_log("Unsupported password/security hash: ".$app->config('sec')->{hash}."! Check your configuration file!");
	}
	my $revs=IPWS::Password::Revision::Manager->get_pwrev(
		sort_by => 'id DESC',
		limit => 1
	);
	my $rev;
	if ($revs && $revs->[0] &&
		$revs->[0]->hash eq $app->config('sec')->{hash} &&
		$revs->[0]->libver eq $VERSION
		) {
		$rev=$revs->[0];
	}else{
		$rev=IPWS::Password::Revision->new(
			hash => $app->config('sec')->{hash},
			libver => $VERSION
		)->save;
	}
	$opts{hash}=$rev->hash;
	$opts{salt_size}=$app->config('sec')->{salt_size};
	$latest_rev=$rev;
	return $rev;
}

1;

=pod

=head1 IPWS::Password - password management for IPWS.

=head2 SYNOPSIS

# at startup() or when config's sec section changes:
IPWS::Password->latest_rev($app); #idempotent

# Writes directly to database.
# idempotent except for when the user's password rev is outdated
IPWS::Password->create($user,$password);

# This is nullipotent
IPWS::Password->check($user,$password);
