package PoProdSumm;

BEGIN {
	require CSVFile;
	push @ISA , 'CSVFile';
}

use strict;

sub new {
	my $class = shift;

	my $self = $class->SUPER::new ( 
					file	=> undef ,
					@_ , 
					keyFlds => [ 'Broker Number' ] ,
					ignoreFlds => [ 'Broker Name' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

sub totalNetFee {
	my $self = shift;
	return $self->val ( {} , 'Total  Fee' );
}

sub poNetFee {
	my $self = shift;
	my ( $po ) = @_;
	return $self->val ( { 'Broker Number' => $po } , 'Total  Fee' );
}

1;
