#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use STAMP::STAMPBook;
use SymbolBook;


our $PRE_OPEN_THRESH_TIME = "09:25:00.000000000";

our %symInfoMap =  ();

our $debug;
our $spreadGoal;

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

# ---------------------------------------------
# Returns:
# 	 1 if price is better than reference price; 
#	-1 if price is worse than reference price;
#	 0 if prices are equal
# ---------------------------------------------
sub cmpPrice {
	my ( $refPrice , $price , $side ) = @_;
	my $cmp = sprintf "%.3f" , $price - $refPrice;
	$cmp *= -1 if $side eq 'Sell';
	
	return ( $cmp > 0 ? 1 : ( $cmp < 0 ? -1 : 0 ) );
}


sub getSymInfo {
	my ( $symBook ) = @_;
	
	my $symInfo = $symInfoMap{ $symBook->{Sym} };
	if ( !$symInfo ) {
		$symInfo = {
			State			=> undef ,
			UpdateTime		=> undef ,
			TotalTime		=> 0 ,
			Buy		=> {
				WeightedLitVol		=> 0 ,
				WeightedIcebergVol	=> 0 ,
				Dark => {
					WeightedBetterVol	=> 0 ,
					WeightedSameVol		=> 0
				}
			} ,
			Sell	=> {
				WeightedLitVol		=> 0 ,
				WeightedIcebergVol	=> 0 ,
				Dark => {
					WeightedBetterVol	=> 0 ,
					WeightedSameVol		=> 0
				}
			} ,
		};
		$symInfoMap{ $symBook->{Sym} } = $symInfo;
	}
	return $symInfo;
}

sub setState {
	my ( $timeStamp , $symInfo , $symBook ) = @_;
	if ( $symBook->{StockState} eq 'Authorized' ) {
		my $mktState = $symBook->{MktState};
		$symInfo->{State} = ( $mktState eq 'Open' || $mktState eq 'MOC Imbalance' ) ? "Open" :
							( $mktState eq 'Pre-open' || $mktState eq 'Opening' ) ? "Pre-open" :
							"Closed";
	}
	else {
		( $symInfo->{State} = $symBook->{StockState} ) =~ s/Authorized//;
	}
	print STDERR "[$timeStamp] : Setting state [$symBook->{Sym}] stock state [$symBook->{StockState}] mkt state [$symBook->{MktState}] ==> [$symInfo->{State}]...\n";
}

sub applyStateTransition {
	my ( $timeStamp , $symBook ) = @_;
	my $symInfo = getSymInfo ( $symBook );
	
	my $prevSymState = $symInfo->{State};
	setState ( $timeStamp , $symInfo , $symBook );

	if ( $prevSymState ne 'Open' && $symInfo->{State} eq 'Open' ) {
	
#		If transitioning from Pre-open to Open, reset the update time.
#		--------------------------------------------------------------
		print STDERR "Transitioning from not-open to open...\n";
		$symInfo->{UpdateTime} = $timeStamp;
	}
	
#	If transitioning from Open to non-Open, process the final Open interval.
#	------------------------------------------------------------------------
	elsif ( $prevSymState eq 'Open'  && $symInfo->{State} ne 'Open' ) {
		print STDERR "...transitioning from open to not-open...\n";
		updateSymInfo ( $timeStamp , "CLOSE" ,  , $symBook , 1 );
	}
}

sub updateSymInfo {
	my ( $timeStamp , $event , $symBook , $symStateOverride ) = @_;
	
	my $symInfo = getSymInfo ( $symBook );
	my $elapsed = tsDiff ( $symInfo->{UpdateTime} , $timeStamp );
	
	return if !$symStateOverride && $symInfo->{State} ne 'Open';
	
	foreach my $side ( qw ( Buy Sell ) ) {
		my $litBook = $symBook->{BookMap}->{Boardlot}->{$side};
		my $darkBook = $symBook->{BookMap}->{Dark}->{$side};
		
		my $litTopLvl = $litBook->getTopLvl ();
		my $litTopPrice;
		my ( $litQty , $icebergQty , $darkBetterQty , $darkSameQty ) = ( 0 , 0 , 0 , 0 );
		if ( $litTopLvl ) {
			$litTopPrice = $litTopLvl->{Price};
			$litQty = $litTopLvl->totalQty ();
			$icebergQty = $litTopLvl->totalIcebergQty ();
		}
		else {
			$litTopPrice = ( $side eq 'Buy' ? -1 : 999 );
		}	
				
		foreach my $darkLvl ( $darkBook->getLvls() ) {
			my $isBetterPrice = cmpPrice ( $litTopPrice , $darkLvl->{Price} , $side );
			last if $isBetterPrice < 0;
			if ( $isBetterPrice ) {
				$darkBetterQty += $darkLvl->totalQty ();
			}
			else {
				$darkSameQty += $darkLvl->totalQty ();
			}
		}
		
		$symInfo->{$side}->{WeightedLitVol} += $elapsed * $litQty;
		$symInfo->{$side}->{WeightedIcebergVol} += $elapsed * $icebergQty;
		$symInfo->{$side}->{Dark}->{WeightedBetterVol} += $elapsed * $darkBetterQty;
		$symInfo->{$side}->{Dark}->{WeightedSameVol} += $elapsed * $darkSameQty;
	}
	
	$symInfo->{UpdateTime} = $timeStamp;
	$symInfo->{TotalTime} += $elapsed;
	
#	print STDERR "$timeStamp $event : [" , Dumper ( $symInfo ) , "]\n";
}

sub mktStateCB {
	my ( $timeStamp , $symBook ) = @_;

	print STDERR "[$timeStamp] : MKT STATE [$symBook->{Sym}] NOW [$symBook->{MktState}]...\n";
	applyStateTransition ( $timeStamp , $symBook );
}

sub symStatusCB {
	my ( $timeStamp , $symBook ) = @_;
	
	print STDERR "[$timeStamp] : SYM STATUS [$symBook->{Sym}] NOW [$symBook->{StockState}]...\n";
	applyStateTransition ( $timeStamp , $symBook );
}

sub quoteCB {
	my ( $timeStamp , $isInternal , $symBook , $rawMsg , $symStateOverride ) = @_;
	
#	--- We care only about internal quote updates ---
	return if !$isInternal;

	updateSymInfo ( $timeStamp , "INT_QUOTE" , $symBook );
}

sub orderCB {
	my ( $timeStamp , $symBook , $rawMsg ) = @_;

#	Process Dark orders and Iceberg Refreshes only, as all others we care about
#	(i.e. at the BBO) will be followed by Quote events.
#	---------------------------------------------------------------------------
	return if ( $rawMsg->getAttr ( "Undisplayed" ) ne 'Y' 
				&& $rawMsg->getAttr ( "IcebergRefresh" ) ne 'Y' );
	
	updateSymInfo ( $timeStamp , "ORDER" , $symBook );
}

sub trdCB {
	my ( $timeStamp , $symBook , $rawMsg , $trdPrice , $trdQty , $isCross , $setsLSP ) = @_;

#	Skip crosses.
#	-------------
	return if $isCross;
	
#	Process Dark-to-Dark trades only, as all others will be followed by Quote events.
#	-------------------------------------------------------------------------------
	return if ( $rawMsg->getAttr ( "Undisplayed.0" ) ne 'Y' 
				&& $rawMsg->getAttr ( "Undisplayed.1" ) ne 'Y' );
	
	updateSymInfo ( $timeStamp , "TRADE" , $symBook );
}

GetOptions ( 
	'd'		=> \$debug ,
);

my $STAMPFile = $ARGV[ 0 ];

my $STAMPBook = new STAMP::STAMPBook ( File => $STAMPFile ,
										SymStatusCallback	=> \&symStatusCB ,
										QuoteCallback		=> \&quoteCB ,
										MktStateCallback	=> \&mktStateCB ,
										TradeCallback		=> \&trdCB ,
										OrderCallback		=> \&orderCB ,
										Debug				=> $debug
									);

$STAMPBook->run;

print "Symbol,OpenTime," ,
		"BuyLitVol,BuyIcebergVol,BuyBetterDarkVol,BuySameDarkVol," ,
		"SellLitVol,SellIcebergVol,SellBetterDarkVol,SellSameDarkVol\n";
		
foreach my $sym ( sort keys %symInfoMap ) {
	my $symInfo = $symInfoMap{ $sym };
	my $elapsed = $symInfo->{TotalTime};

	printf "$sym,%.2f" , $elapsed;
	
	foreach my $side ( qw ( Buy Sell ) ) {
		my $sideInfo = $symInfo->{$side};
		
		printf ( ",%.2f,%.2f,%.2f,%.2f" ,
					$sideInfo->{WeightedLitVol}/$elapsed , 
					$sideInfo->{WeightedIcebergVol}/$elapsed ,
					$sideInfo->{Dark}->{WeightedBetterVol}/$elapsed ,
					$sideInfo->{Dark}->{WeightedSameVol}/$elapsed
		);
	}
	print "\n";
}
__DATA__
	
	my $opSumm = $symSumm->{OpenPresence};
	my $openPresence;
	if ( !$opSumm->{TotalTime} ) {
		print STDERR "WARNING - no opening total time for [$sym]\n";
		$openPresence = 0;
	}
	else {
		$openPresence = $opSumm->{Presence} / $opSumm->{TotalTime};
	}
	
	my $nbboSumm = $symSumm->{NBBOTime};
	my $nbboPresence;
	if ( !$nbboSumm->{TotalTime} ) {
		print STDERR "WARNING - no NBBO total time for [$sym]\n";
		$nbboPresence = 0;
	}
	else {
		$nbboPresence = ( $nbboSumm->{NBBTime} / $nbboSumm->{TotalTime} + $nbboSumm->{NBOTime} / $nbboSumm->{TotalTime} ) / 2;
	}
	
	my $spreadSumm = $symSumm->{Spread};
	my $totalTime = $spreadSumm->{TotalTime};
	my ( %spreadThreshMap , %twaSpreadMap );

	my %spreadGoalMap = ( Abs => $spreadGoal , Rel => 0.05 );

	foreach my $type ( qw ( Abs Rel ) ) {
		
		my $totSpreadTime = 0;
		foreach my $spread ( sort { $a <=> $b } keys %{ $spreadSumm->{$type}->{TimeBySpread} } ) {
			my $spreadTime = $spreadSumm->{$type}->{TimeBySpread}{ $spread };
			$totSpreadTime += $spreadTime;
			
			printf STDERR "SPREAD,$type,$sym,%.6f,%.6f,%.6f,%.6f\n" , $spread , $spreadTime , $totSpreadTime , $totSpreadTime / $totalTime;
			if ( $totSpreadTime / $totalTime >= .95 && !exists $spreadThreshMap{ $type } ) {
				printf STDERR "...HERE...\n";
				$spreadThreshMap{ $type } = $spread;
	#			last;
			}
		}
		
		if ( !$totalTime ) {
			print STDERR "WARNING - no TWA Spread total time for [$sym]\n";
			$twaSpreadMap{ $type } = 0;
		}
		else {
			$twaSpreadMap{ $type } = $spreadSumm->{$type}->{WeightedSpread} / $totalTime;
		}
	}
	
	my $sizeSumm = $symSumm->{Size};
	my $twaSize;
	if ( !$sizeSumm->{TotalTime} ) {
		print STDERR "WARNING - no TWA Size total time for [$sym]\n";
		$twaSize = 0;
	}
	else {
		$twaSize = $sizeSumm->{WeightedSize} / $sizeSumm->{TotalTime};
	}
	
	my $trdSumm = $symSumm->{Trade};
	my $totTrds = $trdSumm->{Total};
	my ( %diffThreshMap , %diffThreshPctMap , %trdsWithinSpreadMap );

	foreach my $type ( qw ( Abs Rel ) ) {
		
		my $cumTrds = 0;
		foreach my $diff ( sort { $a <=> $b } keys %{ $trdSumm->{ $type }->{NumByDiff} } ) {
			if ( $diff > $spreadGoalMap{ $type } && !exists $diffThreshPctMap{ $type } ) {
				$diffThreshPctMap{ $type } = $cumTrds / $totTrds;
			}
			my $numTrds = $trdSumm->{$type}->{NumByDiff}{ $diff };
			$cumTrds += $numTrds;
			printf STDERR "TRDDIFF,$type,$sym,%.6f,%d,%d,%.6f (%.6f)\n" , $diff , $numTrds , $cumTrds , $cumTrds / $totTrds , $spreadGoal;
			if ( $cumTrds / $totTrds >= .95 && !exists $diffThreshMap{ $type } ) {
				$diffThreshMap{ $type } = $diff;
			}
		}
		$diffThreshPctMap{ $type } = 1 if !exists $diffThreshPctMap{ $type };
		$diffThreshMap{ $type } = 0 if !exists $diffThreshMap{ $type };
	}
	
	printf "$sym,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.0f,%.6f,%.6f,%.6f,%.6f\n" , 
			$openPresence , $nbboPresence , 
			$spreadThreshMap{ Abs } , $twaSpreadMap{ Abs } , 
			$spreadThreshMap{ Rel } , $twaSpreadMap{ Rel } , 
			$twaSize ,
			$diffThreshMap{ Abs } , $diffThreshPctMap{ Abs } ,
			$diffThreshMap{ Rel } , $diffThreshPctMap{ Rel };
}