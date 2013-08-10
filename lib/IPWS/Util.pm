package IPWS::Util;
use Exporter 'import';
our @EXPORT_OK = qw(serv_query);
use Carp;

sub serv_query {
	my ($service)=@_;
	if (defined $service and not ref $service) {
		croak "The service parameter should be an IPWS::Service or undefined!\n";
	}
	return defined $service ? (
		'or' => [
			'service' => ['*',$service->id],
			'service_type' => $service->type
		]
	) : (
		'service' => '*'
	);
}
