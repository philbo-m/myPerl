#!c:/perl/bin/perl

use strict;
use File::Basename;
use lib dirname $0;

use SOROrder;

sub processTrade {

#	PARENT_CLIENT_ORDER_ID,PARENT_ORDER_ID,CHILD_ORDER_ID,CHILD_CLIENT_ORDER_ID,MARKETPLACE_ORDER_ID,
#	EXECUTION_ID,TSXSOR_ORDER_ID_1,TSXSOR_ORDER_ID_2,ORDER_DATE_TIME,ROUTE,
#	BROKER,SYMBOL,SIDE,SENDER_COMP_ID,AGGRESSIVE_ROUTING_STRATEGY,
#	SESSION_ID,TRADER_ID,ORDER_PHASE,QUANTITY,PRICE,
#	ACTIVE_PASSIVE,DIRECTROUTEORDER,AGGRE_CONFIG,PASSI_CONFIG,JITNEY_PROVIDER

	my ( $rec , $orderMap ) = @_;
	my ( $clOrdID , $tradeID , $po , $sym , $side , $trdrID , $phase , $qty , $price , $actPass )
			= ( split ( /,/ , $rec ) )[ 0 , 7 , 10 , 11 , 12 , 16 , 17 , 18 , 19 , 20 ];
	return if ( $phase ne 'AGGRESSIVE_PHASE' || $actPass ne 'A' );
	
	my $order = $$orderMap{ $po }{ $trdrID }{ $sym }{ $side }{ $clOrdID };
	if ( !$order ) {
		$order = new SOROrder;
		$$orderMap{ $po }{ $trdrID }{ $sym }{ $side }{ $clOrdID } = $order;
	}
	
	$tradeID =~ s/:[^:]*$//;	# --- strip off rightmost component of PURE trade ID ---
	$order->addTrade ( $tradeID , $qty , $price );
}

sub processOrder {
	
#	PARENT_CLIENT_ORDER_ID,PARENT_ORDER_ID,CHILD_ORDER_ID,CHILD_CLIENT_ORDER_ID,ORDER_DATE_TIME,
#	ROUTE,BROKER,SYMBOL,SIDE,SIDE_QUALIFIER,
#	ANONYMOUS,SENDER_COMP_ID,ALGO_TYPE,AGGRESSIVE_ROUTING_STRATEGY,SESSION_ID,
#	TRADER_ID,QUANTITY,JITNEY_PROVIDER,PRICE,MARKETPLACE_ORDER_ID,
#	ORDER_STATUS,ORDER_DURATION,ORDER_LATENCY,DAO_MAKER,ORDER_POSTING_TIME,
#	DIRECTROUTEORDER

	my ( $rec , $orderMap ) = @_;
	my ( $clOrdID , $date , $po , $sym , $side , $trdrID , $qty , $price )
			= ( split ( /,/ , $rec ) )[ 0 , 4 , 6 , 7 , 8 , 15 , 16 , 18 ];
			
	my $order = $$orderMap{ $po }{ $trdrID }{ $sym }{ $side }{ $clOrdID };
	return if !$order;
	
	( $order->{date} = $date ) =~ s/-.*$//;
	$order->{side} = $side;
	$order->{qty} = $qty;
	$order->{price} = $price;
}

my $inTrades = 1;
my %orderMap = ();

while ( <> ) {

	chomp;
	
	if ( $inTrades && /^ORDERS$/ ) {
		$inTrades = 0;
		next;
	}
	elsif ( $inTrades && /^TRADES$/ ) {
		$inTrades = 1;
		next;
	}
	if ( $inTrades ) {
		processTrade ( $_ , \%orderMap );
	}
	else {
		processOrder ( $_ , \%orderMap );
	}
}

foreach my $po ( sort keys %orderMap ) {
	foreach my $trdrID ( sort keys %{ $orderMap{ $po } } ) {
		foreach my $sym ( sort keys %{ $orderMap{ $po }{ $trdrID } } ) {
			foreach my $side ( sort keys %{ $orderMap{ $po }{ $trdrID }{ $sym } } ) {
				foreach my $clOrdID ( sort keys %{ $orderMap{ $po }{ $trdrID }{ $sym }{ $side } } ) {
					my $order = $orderMap{ $po }{ $trdrID }{ $sym }{ $side }{ $clOrdID };
					print "$order->{date},$po,$trdrID,$sym,$side,$clOrdID,$order->{qty},$order->{price}";
					my @lvls = $order->getLvls ();
					foreach my $lvl ( @lvls ) {
						print ",$lvl->{qty},$lvl->{price}";
					}
					print "\n";
				}
			}
		}
	}
}