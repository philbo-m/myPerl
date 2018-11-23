#!c:/perl/bin/perl

use STAMP::STAMPStream;
use Data::Dumper;

sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(\d\d):(\d\d):(\d\d\.\d+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 ) + ( $tp[ 2 ] * 60 ) + $tp[ 3 ];
#		print STDERR "TSDIFF : ts [$_] [$ts[ $#ts ]]\n";
	}
	return ( $ts[ 1 ] - $ts[ 0 ] );
}

my %orderMap = ();
my $orderCount = 0;
my $prevTS;
my $stream = new STAMP::STAMPStream ( Debug => 0 );

while ( my $msg = $stream->next ) {

	my $ts;
	my $orderIncr = 0;
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) && $msg->getAttr ( "TotalVolume" ) ) {
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );		
		my $clOrdID = $msg->getAttr ( "UserOrderId" );
		$ts = $msg->timeStamp;
		my $confType = $msg->getAttr ( "ConfirmationType" );
		
		my ( $addClOrdID , $delClOrdID );
		
		if ( $confType eq 'Booked' || $confType eq 'Accepted' ) {
			$addClOrdID = $clOrdID;
		}
		elsif ( $confType eq 'CFO' ) {
			$addClOrdID = $clOrdID;
			$delClOrdID = $msg->getAttr ( "CFOdUserOrderId" );
		}
		elsif ( $confType eq 'Cancelled' || $confType eq 'Killed' ) {
			$delClOrdID = $clOrdID;
		}
		else {
			print STDERR "Unhandled order msg type [$confType]\n";
			next;
		}
		$prevTS = $ts if !$prevTS;
		
		if ( $delClOrdID ) {
			if ( !delete $orderMap{ $sym }{ $po }{ $delClOrdID } ) {
				print STDERR "Could not find order for [$confType] [$sym] [$po] [$delClOrdID] [$ts]\n";
			}
			else {
				$orderIncr--;
			}
		}
		if ( $addClOrdID ) {
			$orderMap{ $sym }{ $po }{ $addClOrdID } = 1;
			$orderIncr++;
		}
	}

	elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {

		my $sym = $msg->getAttr ( "Symbol" );
		
#		Find each side of the trade in our hash of cached Iceberg orders.
#		-----------------------------------------------------------------
		foreach my $idx ( 0 , 1 ) {
			my $po = $msg->getAttr ( "BrokerNumber" , $idx );
			my $clOrdID = $msg->getAttr ( "UserOrderId" , $idx );
			if ( exists $orderMap{ $sym }{ $po }{ $clOrdID } ) {
				my $remVol = $msg->getAttr ( "RemainingVolume" , $idx );
				if ( !$remVol ) {
					if ( !delete $orderMap{ $sym }{ $po }{ $clOrdID } ) {
						print STDERR "Could not find order for [Trade] [$sym] [$po] [$clOrdID] [$ts]\n";
					}
					else {
						$ts = $msg->timeStamp;
						$orderIncr--;
					}
				}
			}
		}
	}
	if ( $ts ) {
		printf "$prevTS,$ts,%.9f,$orderCount\n" , tsDiff ( $prevTS , $ts );
		$orderCount += $orderIncr;
		$prevTS = $ts;
	}
		
	print STDERR "$i...\n" if !( $i++ % 100000 );
#	print STDERR "[$i] [" , Dumper ( $msg ) , "]\n";	
}

