package STAMP::STAMPNLSPMsg;

use strict;
use parent "STAMP::STAMPMsg";

use Quote;

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	return $self;
}

sub NLSP {
	my $self = shift;
	return $self->getAttr ( "NLSP" );
}

sub dump {
	my $self = shift;
	my  ( $quote ) = @_;
	
	my @dumpFlds = ( STAMP::STAMPMsg::fmtTimeStamp ( $self->getAttr ( "TimeStamp" ) ) ,
						$self->getAttr ( "Symbol" ) ,
						$self->getAttr ( "NLSP" ) . $self->getAttr ( "MarketID" )
					);
	return join ( " " , @dumpFlds );
}

1;

