package STAMP::STAMPOrderMsg;

use strict;
use parent "STAMP::STAMPMsg";

use Order;

sub new {
	my $class = shift;
	my $self = bless ( $class->SUPER::new ( @_ ) );
	
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	
	my $confType = $self->getAttr ( "ConfirmationType" );
	my $isOrderBook;
	
#	This is for OrderBook messages.
#	-------------------------------
	if ( $self->getAttr ( "BusinessAction" ) eq 'OrderBook' ) {
		$isOrderBook = 1;
		$self->setAttr ( "BusinessAction" , $self->getAttr ( "MarketSide" ) );
		$self->setAttr ( "ConfirmationType" , "Booked" );
	}

	my $undisp = $self->getAttr ( "Undisplayed" );
	if ( $undisp eq 'Y' ) {
		my $pegType = $self->getAttr ( "PegType" );
		$self->setAttr ( "PegType" , "Dark" . ( $pegType eq 'M' ? " Midpt" : "" ) );
	}
			
	my $price = $self->getAttr ( "Price" );
	my $publicPrice = $self->getAttr ( "PublicPrice" );
	if ( !$price ) {
		$price = $publicPrice;
	}
	elsif ( $price != $publicPrice && $isOrderBook ) {
		$price = $publicPrice;
	}
	$self->setAttr ( "Price" , $price );
	
	$self->setAttr ( "RemainingVolume" , $self->getAttr ( "Volume" ) );

	my $anon = $self->getAttr ( "Anonymous" );
	if ( $anon eq 'Y' ) {
		$self->setAttr ( "BrokerNumber" , $self->getAttr ( "PrivateBrokerNumber" ) );
	}
}

sub uniqId {
	my $self = shift;
	return join ( "," , $self->getAttr ( "BrokerNumber" ) , $self->getAttr ( "OrderNumber" ) );
}

sub isCXL {
	my $self = shift;
	return ( $self->getAttr ( "ConfirmationType" ) eq 'Cancelled' || $self->getAttr ( "PrivateConfirmationType" ) eq 'Cancelled' );
}

sub isKilled {
	my $self = shift;
	return ( $self->getAttr ( "ConfirmationType" ) eq 'Killed' || $self->getAttr ( "PrivateConfirmationType" ) eq 'Killed' );
}
sub isFrozen {
	my $self = shift;
	return ( $self->getAttr ( "ConfirmationType" ) eq 'Frozen' || $self->getAttr ( "PrivateConfirmationType" ) eq 'Frozen' );
}
sub isCFO {
	my $self = shift;
	return ( $self->getAttr ( "ConfirmationType" ) eq 'CFO' );
}

sub isMOC {
	my $self = shift;
	return ( $self->getAttr ( "MOC" ) eq 'Y' );
}

sub isIcebergRefresh {
	my $self = shift;
	return ( $self->getAttr ( "IcebergRefresh" ) eq 'Y' );
}

sub isTriggeredOnStop {
	my $self = shift;
	return ( $self->getAttr ( "PrivateConfirmationType" ) eq 'Triggered' );
}

sub isPeggedTradeable {
	my $self = shift;
	my ( $quote ) = @_;
	
	return if $self->getAttr ( "PegType" ) !~ /Midpt/;
	
	my $side = $self->getAttr ( "BusinessAction" );
	( my $price = $self->getAttr ( "Price" ) ) =~ s/\$//;
	my $nbboMid =  sprintf "%.3f" , ( $quote->{NBBO}[ 0 ] + $quote->{NBBO}[ 1 ] ) / 2;
	return ( ( $side eq 'Buy' && $price >= $nbboMid ) || ( $side ne 'Buy' && $price <= $nbboMid ) );
}

sub getRefOrderNo {
	my $self = shift;
	
	my $pvtOrderNo = $self->getAttr ( "PrivateOrderNumber" );
	return ( $pvtOrderNo ? $pvtOrderNo : $self->getAttr ( "OrderNumber" ) );
}

sub applyTrade {
	my $self = shift;
	my ( $trade , $idx ) = @_;
	
	$self->setAttr ( "RemainingVolume" , $trade->getAttr ( "RemainingVolume.$idx" ) );
}

sub applyCFO {
	my $self = shift;
	my ( $cfo ) = @_;
	
	$self->setAttr ( "ConfirmationType" , "CFO" ); 

	foreach my $attr ( qw ( Anonymous OrderDuration Volume TotalVolume Price CFOdOrderNumber CFOdUserOrderId ) ) {
		my $newVal = $cfo->getAttr ( $attr );
		if ( $newVal ) {
			$self->setAttr ( $attr , $newVal );
		}
	}
}

sub setToKilled {
	my $self = shift;
	$self->setAttr ( "ConfirmationType" , "Killed" );
}

sub mkOrder {
	my $self = shift;
	
	my $po = $self->getAttr ( "BrokerNumber" );
	$po = $self->getAttr ( "PrivateBrokerNumber" ) if !$po;
		
	return new Order ( 
		Symbol				=> $self->getAttr ( "Symbol" ) ,
		OrderType			=> $self->getAttr ( "ConfirmationType" ) ,
		Side				=> $self->getAttr ( "BusinessAction" ) ,
		Quantity			=> $self->getAttr ( "Volume" ) ,
		TotalQuantity		=> $self->getAttr ( "TotalVolume" ) ,
		Price				=> $self->getAttr ( "Price" ) ,
		Undisplayed			=> $self->getAttr ( "Undisplayed" ) ,
		PO					=> $po ,
		TrdrID				=> $self->getAttr ( "UserId" ) ,
		ClOrdID				=> $self->getAttr ( "UserOrderId" ) ,
		OrigClOrdID			=> $self->getAttr ( "CFOdUserOrderId" ) ,
		TimeStamp			=> $self->getAttr ( "TimeStamp" ) ,
		PriorityTimeStamp	=> $self->getAttr ( "PriorityTimeStamp" ) ,
		LongLife			=> $self->getAttr ( "LongLife" )
	);
}


sub dump {
	my $self = shift;
	my ( $quote ) = @_;
	
	my $anon = $self->getAttr ( "Anonymous" );
	my @dumpFlds = ( 	$self->timeStamp , $self->getAttr ( "Symbol" ) , 
						$self->getAttr ( "ConfirmationType" ) ,
						$self->getAttr ( "BusinessAction" ) ,
						$self->getAttr ( "Volume" ) ,
						$self->getAttr ( "Price" ) ,
						$self->getAttr ( "OrderDuration" ) ,
						$self->getAttr ( "BrokerNumber" ) . ( $anon ? "(Anon)" : "" ) ,
						$self->getAttr ( "UserId" ) ,
						$self->getAttr ( "OrderNumber" )
						);
	
	return join ( "," , @dumpFlds );
}

1;