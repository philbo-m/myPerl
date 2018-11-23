package RTTraderSymCredit;

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
					keyFlds => [ 'Broker#' , 'Trader ID' , 'Symbol' ] ,
					ignoreFlds => [ 'Broker name' , 'Trader name' , 'Tiering' , 'Performance Score' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

1;
	
	

		

