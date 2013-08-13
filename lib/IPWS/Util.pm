package IPWS::Util;
use Exporter 'import';
our @EXPORT_OK = qw(serv_query sort_perms);
use Carp;

sub serv_query {
	my ($service)=@_;
	return defined $service ? (ref $service ? (
			'or' => [
				'service' => ['*',$service->id],
				'service_type' => $service->type
		] ) : (
			'service' => ['*',$service]
		)
	) : (
		'service' => '*'
	);
}

sub sort_perms {
	sort _sort_perms @{$_[0]};
}

sub _sort_perms {
	my @a_dots=split /\./, $a->name;
	my @b_dots=split /\./, $b->name;
	return 1 if $a->service_type and not $b->service_type;
	return -1 if $b->service_type and not $b->service_type;
	return 1 if $a->service eq '*' and $b->service ne '*';
	return -1 if $b->service eq '*' and $a->service ne '*';
	return $#b_dots <=> $#a_dots if $#a_dots ne $#b_dots;
	return 1 if $a_dots[-1] eq '*';
	return -1 if $b_dots[-1] eq '*';
	return 0;
}
