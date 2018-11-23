package STAMP::STAMPStockInitMsg;

use strict;
use parent "STAMP::STAMPMsg";

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	return $self;
}

1;