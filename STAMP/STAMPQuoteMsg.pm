package STAMP::STAMPQuoteMsg;

use strict;
use parent "STAMP::STAMPMsg";

use Quote;

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	
	$self->setAttr ( "BusinessClass" , $self->getAttr ( "BusinessClass" ) eq 'ABBOIntQuote' ? 'ABBO' : 'CBBO' );
}							
	
sub BBO {
	my $self = shift;
	return ( $self->getAttr ( "BidPrice" ) , $self->getAttr ( "AskPrice" ) );
}

sub BBOQty {
	my $self = shift;
	return ( $self->getAttr ( "BidSize" ) , $self->getAttr ( "AskSize" ) );
}

sub isLocal {
	my $self = shift;
	return ( $self->getAttr ( "BusinessClass" ) eq 'CBBO' );
}

sub dump {
	my $self = shift;
	my  ( $quote ) = @_;
	
	my @dumpFlds = ( STAMP::STAMPMsg::fmtTimeStamp ( $self->getAttr ( "TimeStamp" ) ) ,
						$self->getAttr ( "Symbol" ) ,
						$self->getAttr ( "BusinessClass" ) ,
						$self->getAttr ( "BidSize" ) . "|" . $self->getAttr ( "BidPrice" ) ,
						"--" , 
						$self->getAttr ( "AskPrice" ) . "|" . $self->getAttr ( "AskSize" )
					);
	return join ( " " , @dumpFlds );
}

1;

