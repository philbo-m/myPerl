#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use STAMP::STAMPBook;
use SymbolBook;

my $STAMPFile;

our $PRE_OPEN_THRESH_TIME = "09:25:00.000000000";

our %symInfoMap =  ();

our $debug;
our $spreadGoal;

sub usageAndExit {
	print STDERR "Usage : " , basename $0 , " -g spreadGoal [-d]\n";
	print STDERR "    spreadGoal should be a decimal between 0 and 1.\n";
	print STDERR "    Use '-d' for verbose debug output.\n";
	exit 1;
}

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

sub getSymInfo {
	my ( $symBook ) = @_;
	my $symInfo = $symInfoMap{ $symBook->{Sym} };
	if ( !$symInfo ) {
		$symInfo = {
			MktState		=> undef ,
			Quote			=> undef ,
			LSP				=> $symBook->{LastSale} ,
			UpdateTime		=> undef ,
			BBPresence		=> undef ,
			BOPresence		=> undef ,
			LastTrade		=> undef ,
			Summ 			=> {
									OpenPresence =>	{
										TotalTime	=> undef ,
										Presence	=> undef
									} ,
									NBBOTime => {
										TotalTime	=> undef ,
										NBBTime		=> undef ,
										NBOTime		=> undef
									} ,
									Spread => {
										TotalTime	=> undef ,
											Abs		=> {
												WeightedSpread	=> undef ,
												TimeBySpread	=> {}
											} ,
											Rel		=> {
												WeightedSpread	=> undef ,
												TimeBySpread	=> {}
											} ,
										
									} ,
									Size => {
										TotalTime		=> undef ,
										WeightedSize	=> undef
									} ,
									Trade => {
										Total		=> undef ,
										Abs			=> {
											NumByDiff	=> {}
										} ,
										Rel			=> {
											NumByDiff	=> {}
										} 
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
	
#		If transitioning from Pre-open to Open, process the final Pre-open interval.
#		Otherwise, just reset the update time.
#		----------------------------------------------------------------------------
		if ( $prevSymState eq 'Pre-open' ) {
			print STDERR "...transitioning from pre-open to open ...\n";
			quoteTest ( $timeStamp , 1 , $symBook , undef , $prevSymState );
		}
		else {
			print STDERR "transitioning from not-open to open...\n";
			$symInfo->{UpdateTime} = $timeStamp;
		}
	}
	
#	If transitioning from Open to non-Open, process the final Open interval.
#	------------------------------------------------------------------------
	elsif ( $prevSymState eq 'Open'  && $symInfo->{State} ne 'Open' ) {
		print STDERR "...transitioning from open to not-open...\n";
		quoteTest ( $timeStamp , 1 , $symBook , undef , $prevSymState );
		
#		...if we are now Closed, null out the Trade (so the next trade, likely on the next day,
#		doesn't count toward the Trade Price Diff metric).
#		---------------------------------------------------------------------------------------
		if ( $symInfo->{State} eq 'Closed' ) {
			$symInfo->{LastTrade} = undef;
		}
	}
}

sub accumNBBOTime {
	my ( $symInfo , $tsDiff ) = @_;

	my $nbboSumm = $symInfo->{Summ}->{NBBOTime};
	$nbboSumm->{TotalTime} += $tsDiff;
	$nbboSumm->{NBBTime} += $tsDiff if $symInfo->{BBPresence};
	$nbboSumm->{NBOTime} += $tsDiff if $symInfo->{BOPresence};
}

sub accumSpread {
	my ( $symInfo , $tsDiff , $quote ) = @_;

	my ( $relSpread , $absSpread );
	my $lastPrice = $symInfo->{LSP};
	if ( !$lastPrice ) {
		$absSpread = 0;
		$relSpread = 0;
	}
	elsif ( !$quote->{NBBO}[ 0 ] || !$quote->{NBBO}[ 1 ] ) {
		$absSpread = $lastPrice;
		$relSpread = 1;
	}
	else {
		$absSpread = $quote->{NBBO}[ 1 ] - $quote->{NBBO}[ 0 ];
		$relSpread = $absSpread / $lastPrice;
		$relSpread = 1 if $relSpread > 1;
	}

	my $spreadSumm = $symInfo->{Summ}->{Spread};
	$spreadSumm->{TotalTime} += $tsDiff;
	$spreadSumm->{Rel}->{WeightedSpread} += ( $relSpread * $tsDiff );
	$spreadSumm->{Rel}->{TimeBySpread}->{$relSpread} += $tsDiff;
	
	$spreadSumm->{Abs}->{WeightedSpread} += ( $absSpread * $tsDiff );
	$spreadSumm->{Abs}->{TimeBySpread}->{$absSpread} += $tsDiff;
}

sub accumTrdPrcDiff {
	my ( $symInfo , $prevPrice , $trdPrice ) = @_;
	
	my $priceDiff = $prevPrice - $trdPrice;
	$priceDiff *= -1 if $priceDiff < 0;
	my $relDiff = $priceDiff / $prevPrice;
	
	my $prcDiffSumm = $symInfo->{Summ}->{Trade};
	$prcDiffSumm->{Total}++;
	$prcDiffSumm->{Abs}->{NumByDiff}->{$priceDiff}++;
	$prcDiffSumm->{Rel}->{NumByDiff}->{$relDiff}++;
}		

sub accumSize {
	my ( $symInfo , $tsDiff , $quote ) = @_;
	
	my $totSize = $quote->{Vol}[ 0 ] + $quote->{Vol}[ 1 ] + ( 2 * $symInfo->{MGFQty} );

	my $sizeSumm = $symInfo->{Summ}->{Size};
	$sizeSumm->{TotalTime} += $tsDiff;
	$sizeSumm->{WeightedSize} += ( $totSize * $tsDiff );
#	print STDERR "...[$tsDiff] [$totSize] [$sizeSumm->{TotalTime}] [$sizeSumm->{WeightedSize}]...\n";
}

sub accumOpening {
	my ( $symInfo , $tsDiff , $isPresent ) = @_;
	
	my $openSumm = $symInfo->{Summ}->{OpenPresence};	
	$openSumm->{TotalTime} += $tsDiff;
	$openSumm->{Presence} += $tsDiff if $isPresent;
}

sub mkQuoteLSPRec {
	my ( $eventType , $sym , $prevTimeStamp , $timeStamp , $tsDiff , $symInfo , $quote ) = @_;
	return sprintf "%s,%s,%s,%s,%.9f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d" ,
					$eventType , $sym , $prevTimeStamp , $timeStamp , $tsDiff , 
					$symInfo->{LSP} ,
					$quote->{NBBO}[ 0 ] , $quote->{NBBO}[ 1 ] ,
					$quote->{Vol}[ 0 ] , $quote->{Vol}[ 1 ] ,
					$symInfo->{MGFQty} ,
					$symInfo->{BBPresence} , $symInfo->{BOPresence};
}
	
sub quoteTest {
	my ( $timeStamp , $isInternal , $symBook , $rawMsg , $symStateOverride ) = @_;
	
	my $symInfo = getSymInfo ( $symBook );	
	my $symState = ( $symStateOverride ? $symStateOverride : $symInfo->{State} );
	
#	printf STDERR "$timeStamp %.9f $symBook->{MktState} $symState %s\n" , tsDiff ( $symInfo->{UpdateTime} , $timeStamp ) , $symBook->{BBO}->dump;
	
	my $quote = $symBook->{BBO};
	my $prevQuote = $symInfo->{Quote};
		
	if ( $prevQuote ) {
		if ( $symState eq 'Open' || $debug ) {
			my $tsDiff = tsDiff ( $symInfo->{UpdateTime} , $timeStamp );
			
			accumNBBOTime ( $symInfo , $tsDiff );
			accumSpread ( $symInfo , $tsDiff , $prevQuote );
			accumSize ( $symInfo , $tsDiff , $prevQuote );
			
			print mkQuoteLSPRec ( "QUOTE" , $symBook->{Sym} , $symInfo->{UpdateTime} , 
									$timeStamp , $tsDiff , $symInfo , $prevQuote ) , "\n";

		}
		elsif ( $symState eq 'Pre-open' && $timeStamp gt $PRE_OPEN_THRESH_TIME ) {
			my $prevTime = $symInfo->{UpdateTime};
			$prevTime = $PRE_OPEN_THRESH_TIME if $prevTime lt $PRE_OPEN_THRESH_TIME;
			my $tsDiff = tsDiff ( $prevTime , $timeStamp );

			my $isPresent = ( $prevQuote->{Vol}[ 0 ] > 0 && $prevQuote->{Vol}[ 1 ] > 0 );
			accumOpening ( $symInfo , $tsDiff , $isPresent );
			
			printf "PRE-OPEN,%s,%s,%s,%.9f,%d,%d,%d\n" ,
					$symBook->{Sym} ,
					$prevTime , $timeStamp , $tsDiff , 
					$prevQuote->{Vol}[ 0 ] , $prevQuote->{Vol}[ 1 ] ,
					$isPresent;
		}
	}
	$symInfo->{Quote} = $quote->clone;
	$symInfo->{BBPresence} = ( ( $quote->{NBBO}[ 0 ] == $quote->{LBBO}[ 0 ] ) && $quote->{NBBO}[ 0 ] > 0 );
	$symInfo->{BOPresence} = ( ( $quote->{NBBO}[ 1 ] == $quote->{LBBO}[ 1 ] ) && $quote->{NBBO}[ 1 ] > 0 );
	$symInfo->{UpdateTime} = $timeStamp;

	if ( $isInternal && ( $symState eq 'Open' || $debug ) ) {
		my ( $retVal , $bookQuote ) = $symBook->auditQuote;
		if ( !$retVal ) {
			print STDERR "[$timeStamp] : QUOTE MISMATCH [$symBook->{Sym}]:\n" ,
						"LBBO : " , $symBook->{BBO}->dump ( 1 ) , "\n" ,
						"BOOK : " , join ( " | " , @$bookQuote ) , "\n";
		}
	}
}

sub trdTest {
	my ( $timeStamp , $symBook , $rawMsg , $trdPrice , $trdQty , $isCross , $setsLSP ) = @_;

#	Skip trades that don't set the LSP.
#	-----------------------------------
	return if !$setsLSP;
	
	my $symInfo = getSymInfo ( $symBook );
	my $prevTrade = $symInfo->{LastTrade};

#	Process trade interval, unless this is a Cross.
#	-----------------------------------------------
	if ( !$isCross ) {

#		Report on this trade interval if we are in Continuous and we have a previous trade.
#		------------------------------------------------------------------------------------
		if ( $prevTrade && $symInfo->{State} eq 'Open' ) {
			printf "TRADE,$symBook->{Sym},$timeStamp,$prevTrade->{Price},$prevTrade->{Qty},$trdPrice,$trdQty,%.3f\n" , $trdPrice - $prevTrade->{Price};

			if ( $prevTrade->{Price} ) {	# --- should always be true ---
				accumTrdPrcDiff ( $symInfo , $prevTrade->{Price} , $trdPrice );
			}
		}
		
#		Save trade for next trade interval.
#		-----------------------------------
		$symInfo->{LastTrade} = {
									TimeStamp	=> $timeStamp ,
									Price		=> $trdPrice ,
									Qty			=> $trdQty
								};
	}
	
#	Report on spread if we are in Continuous, and this trade's price is different from the LSP.
#	-------------------------------------------------------------------------------------------
	if ( $symInfo->{State} eq 'Open' && $symInfo->{LSP} && $trdPrice != $symInfo->{LSP} ) {
		my $quote = $symInfo->{Quote};
		my $tsDiff = tsDiff ( $symInfo->{UpdateTime} , $timeStamp );
		
		accumNBBOTime ( $symInfo , $tsDiff );
		accumSpread ( $symInfo , $tsDiff , $quote );
		accumSize ( $symInfo , $tsDiff , $quote );
		
		print mkQuoteLSPRec ( "LSP" , $symBook->{Sym} , $symInfo->{UpdateTime} , 
								$timeStamp , $tsDiff , $symInfo , $quote ) , "\n";

		$symInfo->{UpdateTime} = $timeStamp;
	}
	
#	Save trade price as LSP.
#	------------------------
	$symInfo->{LSP} = $trdPrice;
}

sub mktStateTest {
	my ( $timeStamp , $symBook ) = @_;

	print STDERR "[$timeStamp] : MKT STATE [$symBook->{Sym}] NOW [$symBook->{MktState}]...\n";
	applyStateTransition ( $timeStamp , $symBook );
}

sub symStatusTest {
	my ( $timeStamp , $symBook ) = @_;
	
	print STDERR "[$timeStamp] : SYM STATUS [$symBook->{Sym}] NOW [$symBook->{StockState}]...\n";
	applyStateTransition ( $timeStamp , $symBook );
	
	my $symInfo = getSymInfo ( $symBook );
	$symInfo->{MGFQty} = $symBook->{MGFQty};
	$symInfo->{MGFQty} -= $symInfo->{MGFQty} % $symBook->{BoardLotSize} if $symInfo->{MGFQty} % $symBook->{BoardLotSize};	
}

sub orderTest {
	my ( $timeStamp , $symBook , $rawMsg ) = @_;

	my $symInfo = getSymInfo ( $symBook );	
	my $symState = $symInfo->{State};
	
	if ( $symState eq 'XXX' || $debug ) {
		my ( $retVal , $bookQuote ) = $symBook->auditQuote;
		if ( !$retVal ) {
			print STDERR "[$timeStamp] : AFTER ORDER QUOTE MISMATCH [$symBook->{Sym}]:\n" ,
						"LBBO : " , $symBook->{BBO}->dump ( 1 ) , "\n" ,
						"BOOK : " , join ( " | " , @$bookQuote ) , "\n";
			$symInfo->{qMism} = $timeStamp if !defined $symInfo->{qMism};
		}
		elsif ( $symInfo->{qMism} ) {
			print STDERR "[$timeStamp] : AFTER ORDER QUOTE GOOD [$symBook->{Sym}] AFTER [" , tsDiff ( $symInfo->{qMism} , $timeStamp ) , "]:\n" ,
						"LBBO : " , $symBook->{BBO}->dump ( 1 ) , "\n" ,
						"BOOK : " , join ( " | " , @$bookQuote ) , "\n";			
			$symInfo->{qMism} = undef;
		}
	}
}	

GetOptions ( 
	'd'		=> \$debug ,
	'g=s'	=> \$spreadGoal
) or usageAndExit;

usageAndExit if !$spreadGoal;

$STAMPFile = $ARGV[ 0 ] if !$STAMPFile;

print "PRE-OPEN,Sym,StartTime,EndTime,Duration,LclBidVol,LclAskVol,TMXOpenPresence\n";
print "EVENT,Sym,StartTime,EndTime,Duration,LastSale,NBB,NBO,LclBidVol,LclAskVol,MGF,TMXBBPresence,TMXBOPresence\n";
print "TRADE,Sym,Time,PrevPrice,PrevQty,Price,Qty,PriceDiff\n";

my $STAMPBook = new STAMP::STAMPBook ( File => $STAMPFile ,
										SymStatusCallback	=> \&symStatusTest ,
										QuoteCallback		=> \&quoteTest ,
										MktStateCallback	=> \&mktStateTest ,
										TradeCallback		=> \&trdTest ,
										OrderCallback		=> \&orderTest ,
										Debug				=> $debug
									);

$STAMPBook->run;

print "SUMMARY\n";
print "Symbol,OpenPresence,NBBOPresence,95%AbsSpread,AvgAbsSpread,95%RelSpread,AvgRelSpread," ,
		"TOBSize,95%AbsTrdDiff,TradePctWithinAbsGoal,95%RelTrdDiff,TradePctWithinRelGoal\n";
foreach my $sym ( sort keys %symInfoMap ) {
	my $symSumm = $symInfoMap{ $sym }{ Summ };
	
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