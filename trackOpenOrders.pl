#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use FIXMsg;

package Fill;

sub new {
	my $class = shift;
	my $self = {
		order		=> undef ,
		execID 		=> undef ,
		price		=> undef ,
		qty			=> undef ,
		@_
	};
	
	return bless $self;
}

package Order;

sub new {
	my $class = shift;
	my $self = {
		orderID		=> undef ,
		side		=> undef ,
		qty			=> undef ,
		sym			=> undef ,
		price		=> undef ,
		fills		=> [] ,
		@_
	};
	
	$self->{initOrderID} = $self->{orderID};
	$self->{status} = "O";
	
	return bless $self;
}

sub cxl {
	my $self = shift;
	$self->{status} = "X";
}

sub execQty {
	my $self = shift;
	my $qty = 0;
	foreach my $fill ( @{ $self->{fills} } ) {
		$qty += $fill->{qty};
	}
	return $qty;
}

sub execCap {
	my $self = shift;
	my $cap = 0;
	foreach my $fill ( @{ $self->{fills} } ) {
		$cap += ( $fill->{qty} * $fill->{price} );
	}
	return $cap;
}

sub execPrice {
	my $self = shift;
	return $self->execCap / $self->execQty;
}

sub dump {
	my $self = shift;
	return "[$self->{initOrderID}] [$self->{orderID}] [$self->{side}] [$self->{qty}] [$self->{sym}] [$self->{price}] [" . $self->execQty . "]";
}

package Book;

sub new {
	my $class = shift;
	my $self = {
		buys	=> [] ,
		sells	=> []
	};
	$self->{orderByID} = {};
	
	return bless $self;
}

sub addOrder {
	my $self = shift;
	my ( $order ) = @_;
	my $orderList = ( $order->{side} eq '1' ? $self->{buys} : $self->{sells} );
	push @$orderList , $order;
	$self->{orderByID}{ $order->{orderID} } = $order;
}

sub cxlOrder {
	my $self = shift;
	my ( $clOrdID , $origClOrdID ) = @_;
	
#	--- Find the order ---
	my $order = $$self->{orderByID}{ $origClOrdID };
	if ( !$order ) {
		$order = $$self->{orderByID}{ $clOrdID };
	}
	if ( !$order ) {
		print STDERR "Cannot CXL order with origClOrdID [$origClOrdID] and clOrdID [$clOrdID] - cannot find orig order\n";
		return;
	}
	$order->cxl;
}

sub dump {
	my $self = shift;
	
	my $str = "";
	foreach my $orderList ( $self->{buys} , $self->{sells} ) {
		$str .= ( $orderList eq $self->{buys} ? "BUY" : "SELL" ) . ":\n";
		foreach my $order ( @$orderList ) {
			$str .= $order->dump . "\n";
		}
		$str .= "\n";
	}
	return $str;
}
	
package main;

my $delim = "\\|";
	
my %bookMap = ();

while ( <> ) {

	chomp;
	next if /^\s*$/;
		
	my $msg = new FIXMsg ( 
					delim		=> $delim ,
					simple		=> undef ,
					showTags	=> {}
				);
	$msg->parse ( $_ );

	my ( $incr , $execType );
	my $msgType = $msg->fldVal ( 35 );
	if ( $msgType eq 'D' ) {
			
#		--- New order ---
		my $clOrdID = $msg->fldVal ( 11 );
		my $side = $msg->fldVal ( 54 );
		my $qty = $msg->fldVal ( 38 );
		my $sym = $msg->fldVal ( 55 );
		my $price = $msg->fldVal ( 44 );
		my $order = new Order ( 
							orderID	=> $clOrdID ,
							side	=> $side ,
							qty		=> $qty ,
							sym		=> $sym ,
							price	=> $price
						);
		my $book = $bookMap{ $sym };
		if ( !$book ) {
			$book = new Book;
			$bookMap{ $sym } = $book;
		}
		$book->addOrder ( $order );
		print $book->dump , "\n\n";
	}
	
	elsif ( $msgType eq 'F' ) {
	
#		--- Cancellation request ---
		my $clOrdID = $msg->fldVal ( 11 );
		my $origClOrdID = $msg->fldVal ( 41 );
		my $sym = $msg->fldVal ( 55 );
		my $book = $bookMap{ $sym };
		
		$book->cxlOrder ( $origClOrdID , $clOrdID );
		print $book->dump , "\n\n";
	}
	
	elsif ( $msgType eq 'G' ) {
	
#		--- CFO request ---
	
	elsif ( $msgType eq '8' ) {

#		--- Execution report ---
		my $execType = $msg->fldVal ( 150 );
	}
}