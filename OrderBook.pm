package OrderBook;

use strict;

use OrderLevel;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		SymBook 	=> undef , 
		BookType	=> undef ,
		Side		=> undef ,
		Debug		=> undef ,
		@_
	};

	$self->{LvlByPrice} = {};
	$self->{LvlByClOrdID} = {};
	
	return bless $self;
}

# -------------------------------------------------
# Get price levels in the book, from best to worst.
# -------------------------------------------------
sub getLvlPrices {
	my $self = shift;
	
	my @prices = sort { $a <=> $b } keys %{ $self->{LvlByPrice} };
	return ( $self->{Side} eq 'Buy' ? reverse @prices : @prices );
}

# ----------------------------------------------------------------------------------
# Get the price level in the book with the specified price, creating if necessary. 
# ----------------------------------------------------------------------------------
sub getLvl {
	my $self = shift;
	my ( $price ) = @_;

	my $lvl = $self->{LvlByPrice}{ $price };
	if ( !$lvl ) {
		$lvl = new OrderLevel ( Price => $price , OrderBook => $self , Debug => $self->{Debug} );
		$self->{LvlByPrice}{ $price } = $lvl;
	}
	
	return $lvl;
}

# -----------------------------------------------------------
# Get the price level to which the specified ClOrdID belongs.
# -----------------------------------------------------------
sub getLvlByClOrdID {
	my $self = shift;
	my ( $po , $clOrdID ) = @_;
	
	return $self->{LvlByClOrdID}{ $po }{ $clOrdID };
}

# -------------------------------------------------------------------------------------
# Get the best price level in the book, skipping levels whose total quantities are zero 
# (likely indicative of the script not cleaning up after itself).
# -------------------------------------------------------------------------------------
sub getTopLvl {
	my $self = shift;

	my $topLvl;
	foreach my $price ( $self->getLvlPrices () ) {
		my $lvl = $self->{LvlByPrice}{ $price };
		if ( ( $lvl->totalQty )[ 0 ] > 0 ) {
			$topLvl = $lvl;
			last;
		}
	}
	return $topLvl;
}

# -----------------------------------------------------------
# Return price levels in this book, from best to worst price.
# -----------------------------------------------------------
sub getLvls {
	my $self = shift;
	my @lvls = sort { $a->{Price} <=> $b->{Price} } values %{ $self->{LvlByPrice} };
	return ( $self->{Side} eq 'Buy' ? reverse @lvls : @lvls );
}

sub removeLvl {
	my $self = shift;
}	
	
sub addOrder {
	my $self = shift;
	my ( $order ) = @_;
	
#	Order might already be there - e.g. order with OPR Reprice enters + trades immediately, then books with a new price
#	to avoid locking the market.
#	-------------------------------------------------------------------------------------------------------------------
	my $lvl = $self->{LvlByClOrdID}{ $order->{PO} }{ $order->{ClOrdID} };
	if ( $lvl ) {
		$order->{OrigClOrdID} = $order->{ClOrdID};
		$self->cfoOrder ( $order );
	}
	else {
		$lvl = $self->getLvl ( $order->{Price} + 0 );
	
		$self->{LvlByClOrdID}{ $order->{PO} }{ $order->{ClOrdID} } = $lvl;	# --- to refer back to when CXLing or CFOing ---
		$lvl->addOrder ( $order );
	}
}

sub cxlOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	my $lvl = delete $self->{LvlByClOrdID}{ $order->{PO} }{ $order->{ClOrdID} };
	if ( !$lvl ) {
		print STDERR "ERROR : OrderBook : cxlOrder: unknown order [" , $order->dump , "]\n";
		return;
	}
	my $order = $lvl->cxlOrder ( $order );

	if ( $lvl->isEmpty ) {
		print STDERR "OrderBook : [$self->{Side}] [$lvl->{Price}] now empty - removing..\n" if $self->{Debug};
		delete $self->{LvlByPrice}{ $lvl->{Price} };
	}

	return $order;
}

sub cfoOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	my $origLvl = delete $self->{LvlByClOrdID}{ $order->{PO} }{ $order->{OrigClOrdID} };
	if ( !$origLvl ) {
		print STDERR "ERROR : OrderBook [$self->{Side}] [$self->{SymBook}->{Sym}] : cfoOrder: unknown order [" , $order->dump , "]\n";
		return;
	}
	my $origOrder = $origLvl->getOrder ( $order->{PO} , $order->{OrigClOrdID} );
	if ( !$origOrder ) {
		print STDERR "ERROR : OrderBook [$self->{Side}] [$self->{SymBook}->{Sym}] : cfoOrder: could not find orig order [" , $order->dump , "] at [$origLvl->{Price}]\n";
		return;
	}

	$origLvl->removeOrder ( $origOrder );
	if ( $origLvl->isEmpty ) {
		print STDERR "OrderBook : [$self->{Side}] [$origLvl->{Price}] now empty - removing..\n" if $self->{Debug};
		delete $self->{LvlByPrice}{ $origLvl->{Price} };
	}
	
	my $price = $order->{Price} + 0; 
	my $newLvl = $self->getLvl ( $price );
	$newLvl->addOrder ( $order );
	$self->{LvlByClOrdID}{ $order->{PO} }{ $order->{ClOrdID} } = $newLvl;	# --- to refer back to when CXLing or CFOing ---
			
	return $order;
}

sub applyTrade {
	my $self = shift;
	my ( $po , $clOrdID , $qty , $remQty , $price ) = @_;

	my $lvl = $self->{LvlByClOrdID}{ $po }{ $clOrdID };
	if ( !$lvl ) {
		print STDERR "ERROR : orderBook : applyTrade: unknown order [$po] [$clOrdID]\n";
		return;
	}
	print STDERR "OrderBook : Applying trade [$po] [$clOrdID] [$self->{Side}] [$qty] [$remQty] [$price] to lvl [" , join ( ";" , map { "$_=$$lvl{ $_ }" } keys %$lvl ) , "]...\n" if $self->{Debug};
	my $order = $lvl->applyTrade ( $po , $clOrdID , $qty , $remQty , $price );
	if ( $order->{RemQty} <= 0 ) {
		delete $self->{LvlByClOrdID}{ $po }{ $clOrdID };
		if ( $lvl->isEmpty ) {
			print STDERR "OrderBook : [$self->{Side}] [$lvl->{Price}] now empty - removing..\n" if $self->{Debug};
			delete $self->{LvlByPrice}{ $lvl->{Price} };
		}
	}
	
	return $order;
}

sub dump {
	my $self = shift;
	my ( $fullBook ) = @_;
	
	my @lvls;
	if ( $fullBook ) {
		@lvls = sort { $a->{Price} <=> $b->{Price} } values %{ $self->{LvlByPrice} };
	}
	else {
		my $topLvl = $self->getTopLvl;
		@lvls = ( $topLvl ? ( $topLvl ) : () );
	}
	return join ( "\n" , map { $_->dump } @lvls );
}

1;