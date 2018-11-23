package PoClobSumm;

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
					keyFlds => [ 'Broker Number' , 'Broker Name' ] ,
					ignoreFlds => [ 'Date' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

1;
