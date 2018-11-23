package Activ::ActivTradeMsg;

use strict;
use parent "Activ::ActivMsg";

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	return $self;
}

sub timeStamp {
	my $self = shift;
	return $self->getFld ( 'TRD_TIME' );
}

sub hdr {
	my $self = shift;
	return join ( "," , qw ( DATE TIME SYM SIZE PRICE EXCH BUYER SELLER ) );
}

sub dump {
	my $self = shift;
#	return join ( "," , ( $self->getFld ( 'TRD_DATE' ) , $self->getFld ( 'TRD_TIME' ) , $self->{Symbol} , 
	return join ( "," , ( $self->getFld ( 'TRD_TIME' ) , $self->getFld ( 'SYMBOL' ) , 
							$self->getFld ( 'TRD_SIZE' ) , $self->getFld ( 'TRD_PRICE' ) ,
							$self->getFld ( 'TRD_EXCH' ) , $self->getFld ( 'TRD_BUYER' ) , $self->getFld ( 'TRD_SELLER' )
							
						)
				);
}

1;