package STAMP::STAMPTradeMsg;

use strict;
use parent "STAMP::STAMPMsg";

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	
	foreach my $idx ( 0 , 1 ) {
		my $anon = $self->getAttr ( "Anonymous" , $idx );
		if ( $anon eq 'Y' ) {
			$self->setAttr ( "BrokerNumber" , $self->getAttr ( "PrivateBrokerNumber" , $idx ) , $idx );
			$self->setAttr ( "Anonymous" , "Anon" , $idx );
		}
		$self->setAttr ( "ActPsv" , ( ( split ( // , $self->getAttr ( "Exchange-Admin" , $idx ) ) )[ 1 ] eq 'A' ? "Act" : "Psv" ) , $idx );
	}
}

sub isIntentionalCross {
	my $self = shift;
	return ( ( $self->getAttr ( "BrokerNumber" , 0 ) eq $self->getAttr ( "BrokerNumber" , 1 ) )
				&& $self->getAttr ( "UserOrderId" , 0 ) eq $self->getAttr ( "UserOrderId" , 1 ) );
}

sub setsLSP {
	my $self = shift;
	
	my $crossType = $self->getAttr ( "CrossType" );
	return ( $self->getAttr ( "Market" , 0 ) ne 'Oddlot'
			&& ( 
				!$crossType || 
				$crossType eq 'Regular' && !( $self->getAttr ( "ByPass.0" ) )
			)
			&& $self->getAttr ( "WashTrade" , 0 ) ne 'Y'
			&& !( $self->getAttr ( "SettlementTerms" ) )
			&& $self->getAttr ( "BusinessAction" ) ne 'Cancelled'
			&& $self->getAttr ( "TradeCorrection" ) ne 'Y' 
			&& $self->getAttr ( "SelfTrade" ) ne 'Y'
		);

}

sub uniqId {
	my $self = shift;
	my ( $idx ) = @_;
	
	return join ( "," , $self->getAttr ( "BrokerNumber" , $idx ) ,
						$self->getAttr ( "OrderNumber" , $idx )
					);
}

sub dump {
	my $self = shift;
	
	my @dumpFlds = ( $self->timeStamp , 
						$self->getAttr ( "BusinessAction" ) ,
						"" ,
						$self->getAttr ( "Symbol" ) ,
						$self->getAttr ( "Volume" ) , 
						$self->getAttr ( "Price" ) ,
						$self->getAttr ( "ActPsv" , 0 ) ,
						$self->getAttr ( "BrokerNumber" , 0 ) . ( $self->getAttr ( "Anonymous" , 0 ) ? "(Anon)" : "" ) ,
						$self->getAttr ( "UserId" , 0 ) ,
						$self->getAttr ( "OrderNumber" , 0 ) ,
						$self->getAttr ( "ActPsv" , 1 ) ,
						$self->getAttr ( "BrokerNumber" , 1 ) . ( $self->getAttr ( "Anonymous" , 1 ) ? "(Anon)" : "" ) ,
						$self->getAttr ( "UserId" , 1 ) ,
						$self->getAttr ( "OrderNumber" , 1 )
					);
	return join ( "," , @dumpFlds );
}

1;

