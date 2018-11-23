package SymbolBook;

use strict;
use Data::Dumper;

use OrderBook;
use Quote;

sub new {
	my $class = shift;
	my $self = {
		Sym				=> undef ,
		BoardLotSize	=> undef ,
		StockGrp		=> undef ,
		MGFQty			=> 0 ,
		MktState		=> undef ,
		StockState		=> undef ,
		StatusDate		=> undef ,
		LastSale		=> undef ,
		Debug			=> undef ,
		@_
	};
	bless $self;

	$self->initBooks;
	$self->{OnStopMap} = {};
	
	return $self;
}

sub initBooks {
	my $self = shift;

	$self->{BookMap} = {
		Boardlot => {
			Buy		=> new OrderBook ( Side => "Buy" , SymBook => $self , BookType => 'Boardlot' , Debug  => $self->{Debug} ) ,
			Sell	=> new OrderBook ( Side => "Sell" , SymBook => $self , BookType => 'Boardlot' , Debug  => $self->{Debug} ) ,
			BookByClOrdID	=> {}
		} , 
		Oddlot => {
			Buy		=> new OrderBook ( Side => "Buy" , SymBook => $self , BookType => 'Oddlot' , Debug  => $self->{Debug} ) ,
			Sell	=> new OrderBook ( Side => "Sell" , SymBook => $self , BookType => 'Oddlot' , Debug  => $self->{Debug} ) ,
			BookByClOrdID	=> {}
		} ,
		Dark => {
			Buy		=> new OrderBook ( Side => "Buy" , SymBook => $self , BookType => 'Dark' , Debug  => $self->{Debug} ) ,
			Sell	=> new OrderBook ( Side => "Sell" , SymBook => $self , BookType => 'Dark' , Debug  => $self->{Debug} ) ,
			BookByClOrdID	=> {}
		}
	};
	$self->{BookByClOrdID} = {};
	
	$self->{BBO} = new Quote;
}

sub addQuote {
	my $self = shift;
	my ( $bidPrice , $askPrice , $bidSize , $askSize , $isLocal ) = @_;
	
	$self->{BBO}->add ( $bidPrice , $askPrice , $bidSize , $askSize , $isLocal );
}

sub auditQuote {
	my $self = shift;
	
	my $buyLvl = $self->{BookMap}{ Boardlot }{ Buy }->getTopLvl;
	my $sellLvl = $self->{BookMap}{ Boardlot }{ Sell }->getTopLvl;
	my $buyPrice = $buyLvl ? $buyLvl->{Price} : 0;
	my $buyVol = $buyLvl ? $buyLvl->totalQty : 0;
	my $sellPrice = $sellLvl ? $sellLvl->{Price} : 0;
	my $sellVol = $sellLvl ? $sellLvl->totalQty : 0;
	
	my $retVal = $self->{BBO}->auditBBO ( $buyPrice , $sellPrice , $buyVol , $sellVol );
	return ( $retVal , [ $buyPrice , $sellPrice , $buyVol , $sellVol ] );
}		

sub splitOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	my $olOrder;
	
	if ( $order->{RemQty} % $self->{BoardLotSize} ) {
		if ( $order->{Quantity} > $self->{BoardLotSize} ) {
			$olOrder = $order->clone;
			foreach my $key ( qw ( Quantity RemQty ) ) {
				$olOrder->{$key} = $order->{$key} % $self->{BoardLotSize};
				$order->{$key} -= $order->{$key} % $self->{BoardLotSize};
			}
			if ( $self->{Debug} ) {
				print STDERR "SymbolBook : SPLITTING MIXED LOT ORDER...\n";
				print STDERR "SymbolBook : ...[" , $order->dump , "]...\n";
				print STDERR "SymbolBook : ...]" , $olOrder->dump , "]...\n";
			}
		}
		else {
			$olOrder = $order;
			$order = undef;
			print STDERR "SymbolBook : ORDER IS ODD LOT [" , $olOrder->dump , "]...\n" if $self->{Debug};
		}
	}
	
	return ( $order , $olOrder );
}
	
sub addOrder {
	my $self = shift;
	my ( $order , $isOnStop ) = @_;
	
#	If booking an On-Stop order that has been previously triggered, its price has probably changed;
#	so delete it and re-book it.
#	-----------------------------------------------------------------------------------------------
	if ( delete $self->{OnStopMap}{ $order->{PO} }{ $order->{ClOrdID} } ) {
		print STDERR "Re-booked On-Stop order [", $order->dump , "]; CXLing/re-adding...\n";
		$self->cxlOrder ( $order );
		$self->addOrder ( $order );
		return;
	}
	elsif ( $isOnStop ) {
		$self->{OnStopMap}{ $order->{PO} }{ $order->{ClOrdID} } = 1;
	}
	
	my $side = $order->{Side};
	my $isDark = $order->{Undisplayed};
	my %orderMap;
	if ( $isDark ) {
		%orderMap = ( Dark => $order );
	}
	else {
		my $olOrder;
		( $order , $olOrder ) = $self->splitOrder ( $order );
		%orderMap = ( Boardlot => $order , Oddlot => $olOrder );
	}

	foreach my $bookName ( keys %orderMap ) {
		my $bookOrder = $orderMap{ $bookName };
		if ( $bookOrder ) {
			print STDERR "SymbolBook : Adding $bookName order [$side] [" , $bookOrder->dump , "]\n" if $self->{Debug};
			my $book = $self->{BookMap}{ $bookName }{ $side };
			$book->addOrder ( $bookOrder );		
			$self->{BookByClOrdID}{ $bookOrder->{PO} }{ $bookOrder->{ClOrdID} }{ $bookName } = $book;
			print STDERR "SymbolBook : Added [$bookOrder->{PO}] [$bookOrder->{ClOrdID}] to [$bookName] book [$book]\n" if $self->{Debug};
		}
	}
}

sub killOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	print STDERR "SymbolBook : Killing order [" , $order->dump , "]\n" if $self->{Debug};
	$self->cxlOrder ( $order , 1 );
}

sub cxlOrder {
	my $self = shift;
	my ( $order , $mayNotExist ) = @_;

	my ( $book , $retOrder );
	foreach my $bookName ( keys %{ $self->{BookMap} } ) {
		$book = delete $self->{BookByClOrdID}{ $order->{PO} }{ $order->{ClOrdID} }{ $bookName };
		if ( $book ) {
			$retOrder = $book->cxlOrder ( $order );
		}
	}

	if ( !$retOrder && !$mayNotExist ) {
		print STDERR "ERROR : SymbolBook : cxlOrder: unknown order [" , $order->dump , "]\n";
		return;
	}
	
	return $retOrder;
}

sub cfoOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	my $po = $order->{PO};
	my $origClOrdID = $order->{OrigClOrdID};
	
	my %orderMap;
	if ( $order->{Undisplayed} ) {
		%orderMap = ( Dark => $order );
	}
	else {
		my $olOrder;
		( $order , $olOrder ) = $self->splitOrder ( $order );
		my %orderMap = ( Boardlot => $order , Oddlot => $olOrder );
	}
	
	print STDERR "SymbolBook : CFO'ing [$po] [$origClOrdID]...\n" if $self->{Debug};
	my ( $book , $retOrder );
	foreach my $bookName ( keys %{ $self->{BookMap} } ) {
		$book = delete $self->{BookByClOrdID}{ $po }{ $origClOrdID }{ $bookName };
		my $bookOrder = $orderMap{ $bookName };
		print STDERR "SymbolBook : ...CHECKING [$bookName] [$book] for [$bookOrder->{PO}] [$bookOrder->{OrigClOrdID}]...\n" if $bookOrder && $self->{Debug};
		if ( $book ) {
			print STDERR "SymbolBook : ...ORIG ORDER FOUND IN [$bookName]...\n" if $self->{Debug};
			if ( $bookOrder ) {
				print STDERR "SymbolBook : ...NEW ORDER TO BE APPLIED TO [$bookName]...\n" if $self->{Debug};
				$retOrder = $book->cfoOrder ( $bookOrder );
				$self->{BookByClOrdID}{ $po }{ $bookOrder->{ClOrdID} }{ $bookName } = $book;
			}
			else {
				my $lvlToCxl = $book->getLvlByClOrdID ( $po , $origClOrdID );
				my $orderToCxl = $lvlToCxl->getOrder ( $po , $origClOrdID );
				print STDERR "SymbolBook : ...CXLING ORIG ORDER [" , $orderToCxl->dump , "] in [$bookName]...\n" if $self->{Debug};
				$retOrder = $book->cxlOrder ( $orderToCxl );
			}
		}
		elsif ( $bookOrder ) {
			$self->addOrder ( $bookOrder );
		}
	}

	if ( !$retOrder ) {
		print STDERR "ERROR : SymbolBook : cfoOrder: unknown order [$po] [$origClOrdID]\n";
		return;
	}
	
	return $retOrder;
}

sub applyTrade {
	my $self = shift;
	my ( $po , $clOrdID , $qty , $remQty , $price , $lastSale , $mkt ) = @_;

	my $book = $self->{BookByClOrdID}{ $po }{ $clOrdID }{ $mkt };
	if ( !$book ) {
	
#		Probably not an issue as trades related to active and odd-lot orders, and MGF executions,
#		would not have been booked prior.
#		-----------------------------------------------------------------------------------------
		print STDERR "INFO : symbolBook : applyTrade: unknown order [$po] [$clOrdID] in [$mkt] book\n";
		return;
	}

	print STDERR "SymbolBook : Applying trade [$po] [$clOrdID] [$qty] [$remQty] [$price] to [$mkt]...\n" if $self->{Debug};
	my $retOrder = $book->applyTrade ( $po , $clOrdID , $qty , $remQty , $price );
	
	if ( !$retOrder->{RemQty} ) {
		delete $self->{BookByClOrdID}{ $po }{ $clOrdID }{ $mkt };
	}
	
	$self->{LastSale} = $lastSale;
	
	return $retOrder;
}

sub mkTrdrIDBook {
	my $self = shift;
	my ( $trdrID ) = @_;
	
	my $newBook = new SymbolBook ( %$self );
	
	foreach my $side ( qw ( Buy Sell ) ) {
		foreach my $lvl ( $self->{BookMap}{ Boardlot }{ $side }->getLvls ) {
			foreach my $order ( grep { $_->{TrdrID} eq $trdrID } $lvl->getOrders ) {
				$newBook->addOrder ( $order );
			}
		}
	}
	
	return $newBook;
}
	

sub dump {
	my $self = shift;
	
	my $txt = $self->{BBO}->dump;
	foreach my $side ( qw ( Buy Sell ) ) {
		$txt .= "\n${side}";
		( my $sideTxt = $self->{BookMap}{ Boardlot }{ $side }->dump ) =~ s/^/ /mg;
		$txt .= "\n" . $sideTxt;
	}
	
	return $txt;
}					

1;

