package PoNonClobSumm;

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
					keyFlds => [ 'Brkr Numb' , 'Brkr Nam' ] ,
					ignoreFlds => [ 'Date' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

1;
