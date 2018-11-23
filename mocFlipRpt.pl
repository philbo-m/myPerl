#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Data::Dumper;

use Util qw ( min max );
use STAMP::STAMPStream;
use STAMP::STAMPMsg;

use constant {
	CLOSE_TIME	=> 160000000000000
};

sub getTickSize {
	my ( $price ) = @_;
	
	return ( $price < 0.50 ? 0.005 : 0.01 );
}

sub addSymStatusMsg {
	my ( $symMap , $msg ) = @_;
	
	my $sym = $msg->getAttr ( 'Symbol' );
	my $busClass = $msg->getAttr ( 'BusinessClass' );
	if ( $busClass eq 'SymbolInfo' ) {
		( my $fullName = $msg->getAttr ( 'SymbolFullName' ) ) =~ s/,//g;
		my $mocEligible = $msg->getAttr ( 'MOCEligible' );
		if ( $mocEligible eq 'Y' ) {
			$symMap->{ $sym } = {
						Name		=> $fullName ,
						MOCEligible	=> $mocEligible ,
						PrevClose	=> $msg->getAttr ( 'LastSale' ) ,
						Exchange	=> $msg->getAttr ( 'ExchangeId' )
					};
		}
	}
	elsif ( $busClass eq 'StockStatus' ) {
		my $symObj = $symMap->{ $sym };
		return if !$symObj;
		addStockStatus ( $symObj , $msg );
	}
}

sub addStockStatus {
	my ( $symObj , $msg ) = @_;

	if ( $msg->getAttr ( 'StockState' ) eq 'AuthorizedPriceMovementDelayed' ) {
		$symObj->{ Delayed } = 'Closing Delayed';
		$symObj->{ CCP } = $msg->getAttr ( 'CCP' );
	}
}
	
sub addStockInitMsg {
	my ( $symObj , $msg ) = @_;

	$symObj->{ PMEPct } = $msg->getAttr ( 'PME' );
	$symObj->{ CPAPct } = $msg->getAttr ( 'CPA' );
}

sub addMOCImbalMsg {
	my ( $symObj , $msg ) = @_;
	
	my %imbalMap = (
		BuySide		=> 'B' ,
		SellSide	=> 'S'
	);
	
	if ( !$symObj->{ ImbalRefPrice } ) {	# --- only use the FIRST imbalance msg (might be a 2nd if PME) ---
		$symObj->{ ImbalSide } = $imbalMap{ $msg->getAttr ( 'ImbalanceSide' ) };
		$symObj->{ ImbalVol } = $msg->getAttr ( 'ImbalanceVolume' );
		$symObj->{ ImbalRefPrice } = $msg->getAttr ( 'ImbalanceReferencePrice' );
	}
}

sub addNLSPMsg {
	my ( $symObj , $msg ) = @_;

	$symObj->{ LSP } = $msg->getAttr ( 'NLSP' );
#	print STDERR $msg->timeStamp , ": NLSP msg, LSP now: $symObj->{ LSP }\n";
}

sub addTradeMsg {
	my ( $symObj , $msg ) = @_;
	
	my $vol = $msg->getAttr ( 'Volume' );
	my $price = $msg->getAttr ( 'Price' );
	my $mult = ( $msg->getAttr ( 'BusinessAction' ) eq 'Cancelled' ? -1 : 1 );
	my $isMOC = ( $msg->getAttr ( 'MOC' , 0 ) || $msg->getAttr ( 'MOC' , 1 ) );
	my $isExtended;

#	print STDERR $msg->timeStamp , " : $vol , $price , $isMOC\n";
	if ( $isMOC ) {
		$symObj->{ MOCVol } += $vol * $mult;
		$symObj->{ CCP } = $price;
	}
	
	elsif ( $msg->setsLSP () ) {
		
		if ( $symObj->{ ImbalRefPrice } ) {	# --- past the 3:40 imbalance publication ---
			
			if ( $msg->getAttr ( 'TimeStamp' ) < CLOSE_TIME ) {	# --- 20-min VWAP trade ---
#				if ( !$msg->getAttr ( 'PrivateBypass' , 0 )  && !$msg->getAttr ( 'PrivateBypass' , 1 ) ) {
				$symObj->{ VWAPTrds } += $mult;
				$symObj->{ VWAPVol } += $vol * $mult;
				$symObj->{ VWAPVolxPrice } += $vol * $price * $mult;
#				}
			}
			else {	# --- Extended session trade ---
				$isExtended = 1;
			}
		}
		
		$symObj->{ LSP } = $price if !$isExtended;
#		print STDERR $msg->getAttr ( 'TimeStamp' ) , ": Trade, LSP now: $symObj->{ LSP }\n";
	}
#	print STDERR "...MOC Vol now [$symObj->{ MOCVol }]\n";
	
	if ( !$isMOC ) {
		if ( $msg->getAttr ( 'SelfTrade' ) ne 'Y' 
				&& $msg->getAttr ( 'Market' , 0 ) ne 'SpecialTerms' ) { # --- exclude self trades and special-terms trades ---
			$symObj->{ ContVol } += $vol * $mult;
			$symObj->{ ContTrds } += $mult;
		}
	}
}

sub addOrderMsg {
	my ( $symObj , $msg ) = @_;
	
#	Only interested in orders in the 20 min post-MOC-Imbalance period:
#	* Have ImbalRefPrice (MOC Imbalance has been published)
#	* No CCP yet (MOC trading session hasn't begun)
#	* MOC orders only
#	------------------------------------------------------------------
	return if ( $symObj->{ CCP } || !$symObj->{ ImbalRefPrice } || !$msg->getAttr ( 'MOC' ) );
	
	my $side = $msg->getAttr ( 'BusinessAction' );
	my $vol = $msg->getAttr ( 'Volume' );
	my $confType = $msg->getAttr ( 'ConfirmationType' );
	
#	Imbalance change:  NEGATIVE - toward the BUY side ; POSITIVE - toward the SELL side.
#	------------------------------------------------------------------------------------
	my $imbalDir = ( $side eq 'Buy' ?
						( $confType eq 'Cancelled' ? 1 : -1 ) :
						( $confType eq 'Cancelled' ? -1 : 1 )
					);
	$symObj->{ ImbalChg } += $vol * $imbalDir;
}	

sub getPMEBand {
	my ( $symObj ) = @_;
	my ( $lowerRef , $upperRef );
	if ( $symObj->{ LSP } && $symObj->{ VWAP } ) {
		$lowerRef = Util::min ( $symObj->{ LSP } , $symObj->{ VWAP } );
		$upperRef = Util::max ( $symObj->{ LSP } , $symObj->{ VWAP } );
	}
	elsif ( $symObj->{ LSP } ) {
		$lowerRef = $upperRef = $symObj->{ LSP };
	}
	else {
		$lowerRef = $upperRef = $symObj->{ PrevClose };
	}
	my @range = ( $lowerRef * ( 1 - $symObj->{ PMEPct } / 100 ) , 
					$upperRef * ( 1 + $symObj->{ PMEPct } / 100 ) 
				);
	my $tickOffset = 5 * getTickSize ( $symObj->{ PrevClose } );
	if ( 2 * $tickOffset > ( $range[ 1 ] - $range[ 0 ] ) ) {
		my $tickRef = ( $symObj->{ LSP } ? $symObj->{ LSP } : $symObj->{ PrevClose } );
		@range = ( $tickRef - $tickOffset , $tickRef + $tickOffset );
	}
	
	return @range;
}

sub getCPEBand {
	my ( $symObj ) = @_;
	
	my ( $anchorRef , $outerRef );
	
	$anchorRef = ( $symObj->{ LSP } ? $symObj->{ LSP } : $symObj->{ PrevClose } );
	if ( $symObj->{ LSP } && $symObj->{ VWAP } ) {
		$outerRef = ( $symObj->{ ImbalSide } eq 'B' ? 
							Util::max ( $symObj->{ LSP } , $symObj->{ VWAP } ) :
							Util::min ( $symObj->{ LSP } , $symObj->{ VWAP } )
						);
	}
	elsif ( $symObj->{ LSP } ) {
		$outerRef = $symObj->{ LSP };
	}
	else {
		$outerRef = $symObj->{ PrevClose };
	}
	
#	print STDERR Dumper ( $symObj ) , "\n$anchorRef , $outerRef\n";
	my @range;
	if ( $symObj->{ ImbalSide } eq 'B' ) {
		@range = ( $anchorRef , $outerRef * ( 1 + $symObj->{ CPAPct } / 100 ) );
	}
	else {
		@range = ( $outerRef * ( 1 - $symObj->{ CPAPct } / 100 ) , $anchorRef );
	}
	
	return @range;
}


my ( $allOrders );

GetOptions ( 
	'o=s'	=> \$allOrders
) or die;

my %symMap = ();

print "Flip,PME/Delayed,TSESymbol,Name,MOC Eligible,Imbalance Side,Imbalance Vol,Imbalance Ref Price,Closing Price,PreClose LSP,PME %,CPA %,PME Lower,PME Upper,CPA Lower,CPA Upper,VWAP,MOC Traded Vol,Continuous Traded Vol,Continuous Trade Count,PrevClose,Exchange\n";

my $recordSep = $/;
# my $recordSep = chr ( 001 );

my $skipOrders = ( $allOrders ? 0 : 1 );
my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => $skipOrders , Quiet => 1 , RecordSep => $recordSep );

while ( my $msg = $stream->next ) {
	if ( $msg->isa ( "STAMP::STAMPSymStatusMsg" ) ) {
		addSymStatusMsg ( \%symMap , $msg );
	}
	else {
		my $sym = $msg->getAttr ( 'Symbol' );
		my $symObj = $symMap{ $sym };
		next if !$symObj;
	
		if ( $msg->isa ( "STAMP::STAMPStockInitMsg" ) ) {
			addStockInitMsg ( $symObj , $msg );
		}
		elsif ( $msg->isa ( "STAMP::STAMPMOCImbalMsg" ) ) {
			addMOCImbalMsg ( $symObj , $msg );
			$stream->{ SkipOrders } = 0;	# --- start counting orders, to detect flips ---
		}
		elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
			addTradeMsg ( $symObj , $msg );
		}
		elsif ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
			addOrderMsg ( $symObj , $msg );
		}
		elsif ( $msg->isa ( "STAMP::STAMPNLSPMsg" ) ) {
#			addNLSPMsg ( $symObj , $msg );
		}
	}
}

foreach my $sym ( sort keys %symMap ) {
	my $symObj = $symMap{ $sym };
	my $imbalVol = $symObj->{ ImbalVol };
	my $imbalSide = $symObj->{ ImbalSide };
	my $imbalChg = $symObj->{ ImbalChg } * ( $imbalSide eq 'S' ? -1 : 1 );
	my $flip = ( $imbalChg > $imbalVol ? 'Flip' : '' );
	
	$symObj->{ VWAP } = ( $symObj->{ VWAPVol } ? $symObj->{ VWAPVolxPrice } / $symObj->{ VWAPVol } : 0 );
	my @pmeBand = getPMEBand ( $symObj );
	my @cpaBand;
	if ( $symObj->{ Delayed } ) {
		@cpaBand = getCPEBand ( $symObj );
	}
	
	print join ( "," , ( $flip , $symObj->{ Delayed } , $sym , $symObj->{ Name } , 
						$symObj->{ MOCEligible } , $imbalSide , $imbalVol + 0 , $symObj->{ ImbalRefPrice } ,
						$symObj->{ CCP } , $symObj->{ LSP } , $symObj->{ PMEPct } , $symObj->{ CPAPct } ,
						$pmeBand[ 0 ] , $pmeBand[ 1 ] , $cpaBand[ 0 ] , $cpaBand[ 1 ] ,
						$symObj->{ VWAP } , $symObj->{ MOCVol } , $symObj->{ ContVol } , $symObj->{ ContTrds } , $symObj->{ PrevClose } ,
						$symObj->{ Exchange }
					)
				) , "\n";
}
