#!c:/perl/bin/perl

use strict;

use Getopt::Long;
use File::Basename;

use STAMP::STAMPStream;
use Data::Dumper;

use constant {
	MOC_THRESHOLD_TIME		=> '15:40:00.000000000' ,
	MAX_FEE					=> 25.00
};

my %rateMap = (
	HI	=> 0.0025 ,
	LO	=> 0.0002
);

my $scriptName = basename $0;

sub usageAndExit {
	print STDERR "Usage : $scriptName -v volThresh -p pctThresh\n";
	print STDERR " Parses MSCS files and identifies MOC trades and their underlying orders where:\n";
	print STDERR "  - Trade is volThresh shares in size or larger\n";
	print STDERR "  - Both orders are MOC or LOC orders\n";
	print STDERR "  - Both orders are entered before 3:40:00 pm\n";
	print STDERR "  - Trade size is at least pctThresh of each order size\n";
	print STDERR " Specify pctThresh as a percent - e.g. 80, not 0.8, to denote 80%.\n";
	
	exit 1;
}

my ( $TRADE_VOL_THRESH , $ORDER_VOL_PCT_THRESH );
GetOptions ( 
	'v=i'	=> \$TRADE_VOL_THRESH ,
	'p=f'	=> \$ORDER_VOL_PCT_THRESH ,
) or usageAndExit();

usageAndExit() if ( !defined $TRADE_VOL_THRESH || !defined $ORDER_VOL_PCT_THRESH );

$ORDER_VOL_PCT_THRESH /= 100;

my %orderMap = ();
my %poMap = ();

my $stream = new STAMP::STAMPStream ( Debug => 0 );

# --- Header ---
print join ( "," , qw ( Symbol Volume Price BuyPO BuyTrdrID BuyVol BuyPrice BuyTime 
						SellPO SellTrdrID SellVol SellPrice SellTime ) ) , "\n";
						
while ( my $msg = $stream->next ) {

	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) && $msg->getAttr ( "MOC" ) ) {
	
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );		
		my $clOrdID = $msg->getAttr ( "UserOrderId" );
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
		
		if ( $delClOrdID ) {
			if ( !delete $orderMap{ $sym }{ $po }{ $delClOrdID } ) {
				print STDERR "Could not find order for [$confType] [$sym] [$po] [$delClOrdID] [" , $msg->timeStamp , "]\n";
			}
		}
		if ( $addClOrdID ) {
			$orderMap{ $sym }{ $po }{ $addClOrdID } = $msg;
		}
	}

#	--- Only TSX MOC non-autofill trades...
	elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) 
				&& ( $msg->getAttr ( "MOC" , 0 ) eq 'Y' || $msg->getAttr ( "MOC" , 1 ) eq 'Y' ) 
#				&& ( $msg->getAttr ( "RTAutofill" , 0 ) ne 'C' && $msg->getAttr ( "RTAutofill" , 1 ) ne 'C' ) 				
				&& $msg->getAttr ( "ListingMkt" ) eq 'TSE' ) {

		my $sym = $msg->getAttr ( "Symbol" );
		my $vol = $msg->getAttr ( "Volume" );
		
		my $price = $msg->getAttr ( "Price" );
		my $value = $price * $vol;
		my $hiLo = ( $price >= 1.00 ? 'HI' : 'LO' );
		my $fee = $vol * $rateMap{ $hiLo };
		$fee = MAX_FEE if $fee > MAX_FEE;

		my $auto = 0;
		foreach my $i ( 0 , 1 ) {
			if ( $msg->getAttr ( "RTAutofill" , $i ) ) {
				$auto = 1;
#				print STDERR join ( "," , "AUTO" , $sym , $vol , $price , $hiLo , $fee , $i , 
#									$msg->getAttr ( "BrokerNumber" , 1 - $i ) ,
#									$msg->getAttr ( "BrokerNumber" , $i )
#								) , "\n";
			}
		}
		next if $auto;
		
#		if ( $msg->getAttr ( "BrokerNumber" , 0 ) == 13 || $msg->getAttr ( "BrokerNumber" , 1 ) == 13 ) {
#			print STDERR join ( "," , $msg->getAttr ( "BrokerNumber" , 0 ) , $msg->getAttr ( "BrokerNumber" , 1 ) , 
#										$sym , $vol , $price , $hiLo , $vol * $rateMap{ $hiLo } , $fee 
#								) , "\n";
#		}
		
		my @orders = ();
		
#		Find each side of the trade in our hash of cached MOC orders.
#		-------------------------------------------------------------
		foreach my $idx ( 0 , 1 ) {
			my $po = $msg->getAttr ( "BrokerNumber" , $idx );	
			my $isMOC = $msg->getAttr ( "MOC" , $idx );
			
			$poMap{ $po }{ $hiLo }{ VOLUME } += $vol;
			$poMap{ $po }{ $hiLo }{ COUNT }++;
			$poMap{ $po }{ $hiLo }{ VALUE } += $value;
			$poMap{ $po }{ $hiLo }{ FEE } += $fee;
#			if ( $po == 13 ) {
#				print STDERR "...$sym...\n";
#			}
			
#			For correlated MOC orders, look only at trades of sufficient size, both of whose sides is MOC.
#			----------------------------------------------------------------------------------------------
			next if ( $vol < $TRADE_VOL_THRESH || !$isMOC );
			
			my $clOrdID = $msg->getAttr ( "UserOrderId" , $idx );
			my $orderMsg = $orderMap{ $sym }{ $po }{ $clOrdID };
			if ( !$orderMsg ) {
				print STDERR "Could not find order for MOC Trade [$sym] [$idx] [$po] [$clOrdID]\n";
				next;
			}

#			...and whose orders were both placed before the MOC cutoff time.
#			----------------------------------------------------------------- 			
			my $orderTS = $orderMsg->timeStamp;
			if ( $orderTS > MOC_THRESHOLD_TIME ) {
				print STDERR "MOC Trade [$sym] [$idx] [$po] [$clOrdID] : Order placed too late [$orderTS]\n";
				next;
			}
			
#			...and whose orders are both filled above the threshold percentage by the trade.
#			--------------------------------------------------------------------------------
			my $orderVol = $orderMsg->getAttr ( "Volume" );
			if ( $vol < $orderVol * $ORDER_VOL_PCT_THRESH ) {
				print STDERR "MOC Trade [$sym] [$idx] [$po] [$clOrdID] : Trade vol < [$ORDER_VOL_PCT_THRESH] of order vol [$orderVol]\n";
				next;
			}
			push @orders , $orderMsg;
		}
		
		next if scalar ( @orders ) != 2;	# --- Not both orders fulfilled the criteria above ---
		
		my @outFlds = ( $sym , $vol , $msg->getAttr ( "Price" ) );
		foreach my $orderMsg ( @orders ) {
			my $po = $orderMsg->getAttr ( "BrokerNumber" );
			$poMap{ $po }{ $hiLo }{ CORR_VOLUME } += $vol;
			$poMap{ $po }{ $hiLo }{ CORR_COUNT }++;
			$poMap{ $po }{ $hiLo }{ CORR_VALUE } += $value;
			$poMap{ $po }{ $hiLo }{ CORR_FEE } += $fee;
						
			push @outFlds , ( $po , $orderMsg->getAttr ( "UserId" ) ,
								$orderMsg->getAttr ( "Volume" ) , $orderMsg->getAttr ( "Price" ) , $orderMsg->timeStamp );
		}
		print join ( "," , @outFlds ) , "\n";
	}		
}

print join ( "," , qw ( PO HI_ORDERS HI_VOL HI_VAL HI_FEE LO_ORDERS LO_VOL LO_VAL LO_FEE 
						HI_CORR_ORDERS HI_CORR_VOL HI_CORR_VAL HI_CORR_FEE 
						LO_CORR_ORDERS LO_CORR_VOL LO_CORR_VAL LO_CORR_FEE ) 
					) , "\n";
foreach my $po ( sort { $a <=> $b } keys %poMap ) {
	printf "%s,%d,%d,%.2f,%.2f,%d,%d,%.2f,%.2f,%d,%d,%.2f,%.2f,%d,%d,%.2f,%.2f\n" , $po , 
			$poMap{ $po }{ HI }{ COUNT } , $poMap{ $po }{ HI }{ VOLUME } , $poMap{ $po }{ HI }{ VALUE } , $poMap{ $po }{ HI }{ FEE } ,
			$poMap{ $po }{ LO }{ COUNT } , $poMap{ $po }{ LO }{ VOLUME } , $poMap{ $po }{ LO }{ VALUE } , $poMap{ $po }{ LO }{ FEE } ,
			$poMap{ $po }{ HI }{ CORR_COUNT } , $poMap{ $po }{ HI }{ CORR_VOLUME } , $poMap{ $po }{ HI }{ CORR_VALUE } , $poMap{ $po }{ HI }{ CORR_FEE } ,
			$poMap{ $po }{ LO }{ CORR_COUNT } , $poMap{ $po }{ LO }{ CORR_VOLUME } , $poMap{ $po }{ LO }{ CORR_VALUE } , $poMap{ $po }{ LO }{ CORR_FEE };
}

