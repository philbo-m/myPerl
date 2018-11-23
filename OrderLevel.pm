package OrderLevel;

use strict;

use Order;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Price		=> undef , 
		OrderBook	=> undef ,
		Debug		=> undef ,
		@_
	};

	$self->{OrderMap} = {};
	
	return bless $self;
}

sub isEmpty {
	my $self = shift;
	return !scalar keys %{ $self->{OrderMap} };
}

sub getOrder {
	my $self = shift;
	my ( $po , $clOrdID ) = @_;
	
	return $self->{OrderMap}{ $po }{ $clOrdID };
}

sub getOrders {
	my $self = shift;
	
	my @orders = ();
	foreach my $po ( keys %{ $self->{OrderMap} } ) {
		push @orders , values %{ $self->{OrderMap}{ $po } };
	}
	
	return @orders;
}

sub addOrder {
	my $self = shift;
	my ( $order ) = @_;

	print STDERR "OrderLevel : Adding order [" , $order->dump , "]\n" if $self->{Debug};
	$self->{OrderMap}{ $order->{PO} }{ $order->{ClOrdID} } = $order;	
}

sub removeOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	print STDERR "OrderLevel : Removing order [" , $order->dump , "]\n" if $self->{Debug};

	my $origOrder = delete $self->{OrderMap}{ $order->{PO} }{ $order->{ClOrdID} };
	if ( !$origOrder ) {
		print STDERR "ERROR : OrderLevel : removeOrder : cannot find orig order matching [" , $order->dump , "]\n";
		return;
	}
	if ( !scalar keys %{ $self->{OrderMap}{ $order->{PO} } } ) {
		print STDERR "OrderLevel : [$self->{OrderBook}->{Side}] [$self->{Price}] [$order->{PO}] now empty - removing..\n" if $self->{Debug};
		delete $self->{OrderMap}{ $order->{PO} };
	}

	return $origOrder;
}

sub cxlOrder {
	my $self = shift;
	my ( $order ) = @_;
	
	return $self->removeOrder ( $order );
}

sub applyTrade {
	my $self = shift;
	my ( $po , $clOrdID , $qty , $remQty , $price ) = @_;
	
	my $order = $self->{OrderMap}{ $po }{ $clOrdID };
	$order->applyTrade ( $qty , $remQty , $price );
	
	if ( $order->{RemQty} <= 0 ) { # --- might be negative - could be an iceberg that is now either traded out or is about to be refreshed ---
		$self->removeOrder ( $order );
	}
	
	return $order;
}
	
sub totalQty {
	my $self = shift;
	
	my $qty;
	foreach my $po ( keys %{ $self->{OrderMap} } ) {
		foreach my $order ( values %{ $self->{OrderMap}{ $po } } ) {
			$qty += $order->{RemQty};
		}
	}
	return $qty;
}

sub totalIcebergQty {
	my $self = shift;
	
	my $qty;
	foreach my $po ( keys %{ $self->{OrderMap} } ) {
		foreach my $order ( values %{ $self->{OrderMap}{ $po } } ) {
			$qty += ( $order->{TotalQuantity} ? $order->{TotalQuantity} - $order->{RemQty} : 0 );
		}
	}
	return $qty;
}

sub dump {
	my $self = shift;
	
	my $totalQty = $self->totalQty;
	
	my $dumpRec = "$self->{Price} [$totalQty]";
	
	foreach my $po ( keys %{ $self->{OrderMap} } ) {
		foreach my $order ( values %{ $self->{OrderMap}{ $po } } ) {
			$dumpRec .= "\n " . $order->dump;
		}
	}
	return $dumpRec;
}

1;
