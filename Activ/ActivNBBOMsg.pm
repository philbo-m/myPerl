package Activ::ActivNBBOMsg;

use strict;
use parent "Activ::ActivMsg";

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	return $self;
}

sub timeStamp {
	my $self = shift;
	my $ts = $self->getFld ( 'BID_TIME' );
	return ( $ts ? $ts : $self->getFld ( 'ASK_TIME' ) );
}

1;