package PoVolSumm;

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

sub totalVolume {
	my $self = shift;
	return $self->val ( {} , 'Total Volume' );
}

sub poVolume {
	my $self = shift;
	my ( $po ) = @_;
	return $self->val ( { 'Broker Number' => $po } , 'Total Volume' );
}

1;
