#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use STAMP::STAMPMsg;

sub newOrder {
	my ( $orderMap , $sym , $po , $orderKey ) = @_;

	return ( $$orderMap{ $sym }{ $po }{ $orderKey } = {} );
} 
	
sub shuntOrder {
	my ( $orderMap , $dupIdMap , $sym , $po , $orderKey ) = @_;

	$$dupIdMap{ $orderKey }++;
	$$orderMap{ $sym }{ $po }{ $orderKey . "_$$dupIdMap{ $orderKey }" } = delete $$orderMap{ $sym }{ $po }{ $orderKey };
	
	return newOrder ( $orderMap , $sym , $po , $orderKey );
}

my ( $symListFile , %symList , $justBypass );

GetOptions ( 
	's=s'		=> \$symListFile ,
	'b'			=> \$justBypass
) or die;

die "Specify sym list file with '-s' option" if !$symListFile;

open SL , $symListFile or die "Cannot open sym list file [$symListFile] : $!";
while ( <SL> ) {
	chomp;
	$symList{ $_ } = 1;
}
close SL;

my %orderMap = ();
my %trdMap = ();
my %dupIdMap = ();

# Filter input on '39(\.[01])?=IOC'
# ---------------------------------
while ( <> ) {
	chomp;
	print STDERR "$....\n" if !( $. % 100000 );

	my $msg = STAMP::STAMPMsg::newSTAMPMsg ( $_ );
	next if !$msg;
	
	my $sym = $msg->getAttr ( "Symbol" );
	next if !exists $symList{ $sym };
	
	my $vol = $msg->getAttr ( "Volume" );
	
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
	
		if ( $justBypass ) {
			next if !$msg->getAttr ( "ByPass" );
		}
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $confType = $msg->getAttr ( "ConfirmationType" );
		my $pvtConfType = $msg->getAttr ( "PrivateConfirmationType" );
		my $orderKey = $msg->getAttr ( "UserOrderId" ) . ":" . $msg->getAttr ( "PriorityTimeStamp" );
		
		my $totVol = $msg->getAttr ( "TotalVolume" );
		$vol = $totVol if $totVol;
		my $ts = $msg->timeStamp;
		
		my $order = $orderMap{ $sym }{ $po }{ $orderKey };
		
		if ( $confType eq 'Accepted' ) {

			if ( $pvtConfType eq 'Cancelled' ) {	# --- Self-trade probably ---
				if ( !$order ) {
					print STDERR "[$ts] : CXLed msg on unknown order [$sym] [$po] [$orderKey]\n";
				}
				else {
					print STDERR "[$ts] : CXLed msg on [$sym] [$po] [$orderKey] trd vol [$order->{ TrdVol }] - reason code [" , $msg->getAttr ( "ReasonCode" ) , "]\n";
					delete $orderMap{ $sym }{ $po }{ $orderKey };
				}
			}
			else {
				if ( $order ) {
					print STDERR "[$ts] : ACCEPTED msg : Dupe ClOrdID [$sym] [$po] [$orderKey]\n";
					$order = shuntOrder ( \%orderMap , \%dupIdMap , $sym , $po , $orderKey );
				}
				else {
					$order = newOrder ( \%orderMap , $sym , $po , $orderKey );
				}
				$order->{ Vol } = $vol;
#				print STDERR "ACC [$ts] [$sym] [$po] [$orderKey] [$order]...\n";
			}
		}

		elsif ( $confType eq 'Killed' ) {
#			print STDERR "KIL [$ts] [$sym] [$po] [$orderKey] [$order]...\n";
			if ( $order ) {
				if ( $order->{ Done } ) {
					
					# --- Dupe ClOrdID - move previous order aside ---
					print STDERR "[$ts] : KILLED msg : Dupe ClOrdID [$sym] [$po] [$orderKey]\n";
					$order = shuntOrder ( \%orderMap , \%dupIdMap , $sym , $po , $orderKey );
					$order->{ Vol } = $vol;
					$order->{ ExecVol } = 0;
				}
				else {
				
					# --- Not a dupe ---
					$order->{ ExecVol } = $order->{ Vol } - $vol;
				}
			}
			else {
				$order = newOrder ( \%orderMap , $sym , $po , $orderKey );
				$order->{ Vol } = $vol;
				$order->{ ExecVol } = 0;
			}
			$order->{ Done } = 1;
		}
	}
	elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
		my $ts = $msg->timeStamp;
		foreach my $idx ( 0 , 1 ) {
			if ( $msg->getAttr ( "OrderDuration.$idx" ) eq 'IOC' ) {
				if ( $justBypass ) {
					next if !$msg->getAttr ( "ByPass.$idx" );
				}
				my $orderKey = $msg->getAttr ( "UserOrderId.$idx" ) . ":" . $msg->getAttr ( "PriorityTimeStamp.$idx" );
				my $po = $msg->getAttr ( "BrokerNumber.$idx" );
				my $trdId = $msg->getAttr ( "TradeNumber" );
				my $busAct = $msg->getAttr ( "BusinessAction" );
				$vol *= -1 if ( $busAct eq 'Cancelled' );

				my $order = $trdMap{ $sym }{ $po }{ $trdId };
				if ( !$order ) {
					$order = $orderMap{ $sym }{ $po }{ $orderKey };
				}
#				print STDERR "TRD [$ts] [$sym] [$po] [$orderKey] [$order]...\n";
				if ( !$order ) {
					print STDERR "[$ts] INFO: Unknown trade (CFO to IOC?): [$sym] [$vol] [$po] [$orderKey]\n";
					$order = newOrder ( \%orderMap , $sym , $po , $orderKey );
					$order->{ Vol } = $vol + $msg->getAttr ( "RemainingVolume.$idx" );
				}
				$trdMap{ $sym }{ $po }{ $trdId } = $order;
				
				$order->{ TrdVol } += $vol;
				if ( $order->{ TrdVol } == $order->{ Vol } ) {
					$order->{ Done } = 1;
					$order->{ ExecVol } = $order->{ Vol };
				}
				elsif ( $order->{ Done } ) {
					$order->{ ExecVol } += $vol;
				}
				last;
			}
		}
	}
}

foreach my $sym ( sort keys %symList ) {
	my ( $totOrders , $totVol , $totTrdVol , $totExecVol );
	foreach my $po ( keys %{ $orderMap{ $sym } } ) {
		foreach my $orderKey ( keys %{ $orderMap{ $sym }{ $po } } ) {
			$totOrders++;
			my $order = $orderMap{ $sym }{ $po }{ $orderKey };
			my $vol = $order->{ Vol };
			my $trdVol = $order->{ TrdVol } + 0;
			my $execVol = ( exists $order->{ ExecVol } ? $order->{ ExecVol } : $order->{ TrdVol } );
#			print "$sym,$po,$orderKey,$vol,$trdVol,$execVol\n";
			$totVol += $vol;
			$totTrdVol += $trdVol;
			$totExecVol += $execVol; 
		}
	}
	print "$sym,$totOrders,$totVol,$totTrdVol,$totExecVol\n";
}
			
			