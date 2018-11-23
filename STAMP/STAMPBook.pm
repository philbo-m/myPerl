package STAMP::STAMPBook;

use strict;
use Data::Dumper;


use STAMP::STAMPStream;
use STAMP::STAMPMsg;
use SymbolBook;
use StampFld;
use Quote;

sub new {
	my $class = shift;

	my $self = {
		File				=> undef ,
		Debug				=> undef ,
		OrderCallback		=> undef ,
		QuoteCallback		=> undef ,
		TradeCallback		=> undef ,
		MktStateCallback	=> undef ,
		SymStatusCallback	=> undef , 
		BuildBook			=> 1 ,
		@_
	};
	
	$self->{Stream} = new STAMP::STAMPStream ( File => "$self->{File}" , Debug => $self->{Debug} );
	$self->{MasterBook} = {};
	$self->{StockGrpMap} = {};
		
	return bless $self;
}

sub run {
	my $self = shift;
	
	while ( my $msg = $self->{Stream}->next ) {

		my $symBook;	
		my $sym = $msg->getAttr ( "Symbol" );
		if ( $sym ) {
			$symBook = $self->{MasterBook}{ $sym };
			if ( !$symBook && !$msg->isa ( "STAMP::STAMPSymStatusMsg" ) ) {
				print STDERR "STAMPBook : ERROR : unknown message for symbol [$sym] - expected Symbol Status message first\n";
				return;
			}
		}
		$self->applySTAMPMsg ( $symBook , $msg );
	}
}

sub applySTAMPTrade {
	my $self = shift;
	
	my ( $symBook , $STAMPTradeMsg ) = @_;
	
	my %sideMap = ( 0 => 'Buy' , 1 => 'Sell' );
	my $price = $STAMPTradeMsg->getAttr ( "Price" );
	my $qty = $STAMPTradeMsg->getAttr ( "Volume" );
	my $lastSale = $STAMPTradeMsg->getAttr ( "LastSale" );
	
	foreach my $idx ( 0 , 1 ) {
		my $side = $sideMap{ $idx };
		
		my $po = $STAMPTradeMsg->getAttr ( "BrokerNumber.${idx}" );
		my $ClOrdID = $STAMPTradeMsg->getAttr ( "UserOrderId.${idx}" );
		my $remQty = $STAMPTradeMsg->getAttr ( "RemainingVolume.${idx}" );
		my $mkt = $STAMPTradeMsg->getAttr ( "Market.${idx}" );

		print STDERR "STAMPBook : [" , $STAMPTradeMsg->timeStamp , "] : applying trade [$side] [$po] [$ClOrdID] [$qty] [$remQty] [$price]...\n" if $self->{Debug};
		$symBook->applyTrade ( $po , $ClOrdID , $qty , $remQty , $price , $lastSale , $mkt );
	}

	print STDERR "BOOK NOW :\n" , $symBook->dump , "\n\n" if $self->{Debug};
}

sub applySTAMPQuote {
	my $self = shift;
	
	my ( $symBook , $STAMPQuoteMsg ) = @_;

	$symBook->addQuote ( $STAMPQuoteMsg->getAttr ( "BidPrice" ) , $STAMPQuoteMsg->getAttr ( "AskPrice" ) , 
						$STAMPQuoteMsg->getAttr ( "BidSize" ) , $STAMPQuoteMsg->getAttr ( "AskSize" ) ,
						$STAMPQuoteMsg->isLocal
					);
	print STDERR "STAMPBook : [" , $STAMPQuoteMsg->timeStamp , "] : [" , $STAMPQuoteMsg->isLocal ? "INT" : "EXT" , "] QUOTE [" , $symBook->{BBO}->dump , "]...\n" if $self->{Debug};
}

sub applySymbolStatus {
	my $self = shift;
	my ( $symBook , $symStatusMsg ) = @_;
	
	if ( !$symBook ) {
		my $sym = $symStatusMsg->getAttr ( "Symbol" );
		my $stockGrp = $symStatusMsg->getAttr ( "StockGroup" );
		my $stockState = $symStatusMsg->getAttr( "StockState" );
		$symBook = new SymbolBook ( Sym => $sym , StockGrp => $stockGrp , StockState => $stockState ,
									Debug => $self->{Debug} );
		
		$self->{MasterBook}{ $sym } = $symBook;
		push @{ $self->{StockGrpMap}{ $stockGrp } } , $symBook;
	}
	my $date = $symStatusMsg->date;
#	print STDERR "[$symBook->{Sym}] [$symBook->{StockState}] [$date] [$symBook->{StatusDate}]...\n";
	if ( $symBook->{StatusDate} && $symBook->{StatusDate} lt $date ) {
		$symBook->initBooks;
	}
	
	my %attrMap = ( 
			StockState		=> "StockState" ,
			BoardLot		=> "BoardLotSize" ,
			LastSale		=> "LastSale" ,
			"MGF-Setting"	=> "MGFFlag" ,
			"MGF-Volume"	=> "MGFQty" 
		);
	foreach my $attr ( keys %attrMap ) {
		my $val = $symStatusMsg->getAttr ( $attr );
#		print STDERR "...Setting [$attr] [$attrMap{ $attr }] = [$val]\n";
		$symBook->{ $attrMap{ $attr } } = $val if $val;
	}
	
	if ( $symBook->{ MGFFlag } ne 'On' ) {
		$symBook->{ MGFQty } = 0;
	}
	
	$symBook->{StatusDate} = $date;
	
	return $symBook;
}
	
sub applyMktState {
	my $self = shift;
	my ( $mktStateMsg ) = @_;
	
	my $stockGrp = $mktStateMsg->getAttr ( "StockGroup" );
	my $mktState = $mktStateMsg->getAttr ( "MarketState" );
	
	foreach my $symBook ( @{ $self->{StockGrpMap}{ $stockGrp } } ) {
		$symBook->{MktState} = $mktState;
	}
}

sub applySTAMPMsg {
	my $self = shift;
	
	my ( $symBook , $STAMPMsg ) = @_;
	
	if ( $STAMPMsg->isa ( "STAMP::STAMPSymStatusMsg" ) ) {
		$symBook = $self->applySymbolStatus ( $symBook , $STAMPMsg );
		if ( $self->{SymStatusCallback} ) {
			&{ $self->{SymStatusCallback} }( $STAMPMsg->timeStamp , $symBook , $STAMPMsg );
		}
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPMktStateMsg" ) ) {
		$self->applyMktState ( $STAMPMsg );
		if ( $self->{MktStateCallback} ) {
			foreach my $symBook ( @{ $self->{StockGrpMap}{ $STAMPMsg->getAttr ( "StockGroup" ) } } ) {
				&{ $self->{MktStateCallback} }( $STAMPMsg->timeStamp , $symBook , $STAMPMsg );
			}
		}
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPOrderMsg" ) ) {

		if ( $self->{BuildBook} ) {
			my $order = $STAMPMsg->mkOrder;
			print STDERR "STAMPBook : [" , $STAMPMsg->timeStamp , "] : [" , $order->dump , "]...\n" if $self->{Debug};

			if ( $STAMPMsg->isMOC || $STAMPMsg->isFrozen ) {
				return;
			}
			elsif ( $STAMPMsg->isKilled ) {
				$symBook->killOrder ( $order );
			}
			elsif ( $STAMPMsg->isCFO ) {
				$symBook->cfoOrder ( $order );
			}
			elsif ( $STAMPMsg->isCXL ) {
				$symBook->cxlOrder ( $order );
			}
			else {
				$symBook->addOrder ( $order , $STAMPMsg->isTriggeredOnStop );
			}
			print STDERR "BOOK NOW :\n" , $symBook->dump , "\n\n" if $self->{Debug};
		}
		
		if ( $self->{OrderCallback} ) {
			&{ $self->{OrderCallback} }( $STAMPMsg->timeStamp , $symBook , $STAMPMsg );
		}
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPTradeMsg" ) ) {
		if ( $self->{BuildBook} ) {
			$self->applySTAMPTrade ( $symBook , $STAMPMsg );
		}
		if ( $self->{TradeCallback} ) {
			&{ $self->{TradeCallback} }( $STAMPMsg->timeStamp , $symBook , $STAMPMsg ,
											$STAMPMsg->getAttr ( "Price" ) ,
											$STAMPMsg->getAttr ( "Volume" ) ,
											$STAMPMsg->isIntentionalCross ,
											$STAMPMsg->setsLSP
										);
		}
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
		if ( $self->{BuildBook} ) {
			$self->applySTAMPQuote ( $symBook , $STAMPMsg );
		}
		if ( $self->{QuoteCallback} ) {
			&{ $self->{QuoteCallback} }( $STAMPMsg->timeStamp , $STAMPMsg->isLocal , $symBook , $STAMPMsg );
		}
	}		
}

1;