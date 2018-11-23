#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use Billing::FeeConv;

sub abs {
	my ( $v ) = @_;
	return ( $v < 0 ? $v * -1 : $v );
}

sub isBonusEligible {
	my ( $subProd ) = @_;
	return 0;
	return ( $subProd !~ /_(LO_|ETF|OL|MOO|MOC|PART)/ );
}

sub isInterlisted {
	my ( $subProd ) = @_;
	return ( $subProd =~ /_INTL/ );
}

sub isETF {
	my ( $subProd ) = @_;
	return ( $subProd =~ /_ETF/ );
}

my %psvFeeMap = (
	RT		=> { 
					A => { BASE => -0.0013 , BONUS => -0.0016 } ,
					B => { BASE => -0.0014 , BONUS => -0.0019 }
				} ,
	RT_INTL	=>	{ 
					A => { BASE => -0.0025 , BONUS => -0.0028 } ,
					B => { BASE => -0.0026 , BONUS => -0.0030 }
				}
);

my $doBonus = 0;

GetOptions ( 
	'b'		=> \$doBonus ,
) or die;

my %tierBySym = ();
my %intlBySym = ();
my %etfBySym = ();
my %bonusBySymPO = ();
my %feeBySymPO = ();
my %feeBySubProd = ();
my %volBySubProd = ();

# Use the RTTRADERBONUS file to get symbols' Tiers and their Bonus Rate qualifications by PO.
# -------------------------------------------------------------------------------------------
open ( RTB , $ARGV[ 0 ] ) or die ( "Cannot open Bonus Tier file [$ARGV[ 0 ]] : $!" );

<RTB>;	# --- skip header ---
while ( <RTB> ) {
	chomp ; s/"//g;
	my ( $po , $sym , $tier , $thresh , $primSec , $psvPct ) = ( split /,/ )[ 0 , 1 , 2 , 4 , 5 , 8 ];
	
	$tierBySym{ $sym } = substr ( $tier , 0 , 1 );
	if ( $psvPct >= $thresh ) {
		$bonusBySymPO{ $sym }{ $po } = 1;
	}
}
close RTB;

# Get trade quantities + fees from the TDRSALESUM file.
# -----------------------------------------------------
open ( TDRS , $ARGV[ 1 ] ) or die ( "Cannot open Tdrsalesum file [$ARGV[ 1 ]] : $!" );

<TDRS>;	# --- skip header ---
while ( <TDRS> ) {
	chomp ; s/"//g;
	my ( $po , $trdrID , $sym , $subProd , $actVol , $psvVol , $baseFee , $netFee )
			= ( split /,/ )[ 0 , 1 , 3 , 4 , 8 , 9 , 10 , 11 ];
	next if ( $subProd !~ /_RT/ );
	
	$feeBySymPO{ $sym }{ $po }{ BASE } += $baseFee;
	$feeBySymPO{ $sym }{ $po }{ NET } += $netFee;
	
	$volBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ ACT } += $actVol;
	$volBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ PSV } += $psvVol;
	$feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ BASE } += $baseFee;
	$feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ NET } += $netFee;
	
	if ( isInterlisted ( $subProd ) ) {
		$intlBySym{ $sym } = 1;
	}
	if ( isETF ( $subProd ) ) {
		$etfBySym{ $sym } = 1;
	}
}
close TDRS;

foreach my $sym ( sort keys %feeBySymPO ) {
	my $tier = $tierBySym{ $sym };
	my $intl = $intlBySym{ $sym };
	my $etf = $etfBySym{ $sym };
	
	foreach my $po ( sort { $a <=> $b } keys %{ $feeBySymPO{ $sym } } ) {
	
		my $bonus = $bonusBySymPO{ $sym }{ $po };
		my $totCalcNetFee = 0;
		my $totPosCalcNetFee = 0;
		my $totPosActVol = 0;
		my $totPosTrdrIDFee = 0;
		my %netFeeByTrdrID = ();
		my %netPosFeeByTrdrID = ();
		
		foreach my $trdrID ( sort { $a <=> $b } keys %{ $feeBySubProd{ $sym }{ $po } } ) {
		
			foreach my $subProd ( keys %{ $feeBySubProd{ $sym }{ $po }{ $trdrID } } ) {

				my $subProdMap = $feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd };
				my $baseFee = $$subProdMap{ BASE };
				
				if ( isBonusEligible ( $subProd ) && $bonus && $doBonus ) {
				
#					Symbol/PO qualify for bonus rates, and this is a bonus-eligible subproduct.
#					Calculate net fee based on base and bonus rates for this subproduct/tier.
#					---------------------------------------------------------------------------
					my $feeMap = $psvFeeMap{ ( $intl ? 'RT_INTL' : 'RT' ) }{ $tier };
					my $psvVol = $volBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ PSV };
					
					my $baseRate = $$feeMap{ BASE };
					my $bonusRate = $$feeMap{ BONUS };
			
					my $calcNetFee = $baseFee + ( $psvVol * ( $bonusRate - $baseRate ) );
					$$subProdMap{ CALC_NET } = $calcNetFee;
					$totCalcNetFee += $calcNetFee;
					$totPosCalcNetFee += $calcNetFee if $calcNetFee > 0;
				}
				else {
			
#					Not a bonus situation.  Net fee is the same as base fee.
#					--------------------------------------------------------
					$$subProdMap{ CALC_NET } = $baseFee;
					$totCalcNetFee += $baseFee;
					if ( $baseFee > 0 ) {
						my $actVol = $volBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ ACT };
						$totPosActVol += $actVol;
						$totPosCalcNetFee += $baseFee;
					}
				}
				$netFeeByTrdrID{ $trdrID } += $$subProdMap{ CALC_NET };
				if ( $$subProdMap{ CALC_NET } > 0 ) {
					$netPosFeeByTrdrID{ $trdrID } += $$subProdMap{ CALC_NET };
				}
			}
			
			if ( $netFeeByTrdrID{ $trdrID } > 0 ) {
				$totPosTrdrIDFee += $netFeeByTrdrID{ $trdrID };
			}
		}

#		Now that net fees have been calculated, check to see if they're net positive.
#		If so, reduce them to zero (with a reduction cap of 1,000), proportionately 
#		across the TrdrIDs and subproduct(s) whose fees are positive.
#		-----------------------------------------------------------------------------
		if ( $totCalcNetFee > 0 && !$etf ) {
			my $adjNetFee = ( $totCalcNetFee > 20000 ? 20000 : $totCalcNetFee );
			print STDERR "Adjusting [$sym] [$po] [$feeBySymPO{ $sym }{ $po }{ BASE }] [$feeBySymPO{ $sym }{ $po }{ NET }] by $adjNetFee...\n";
			foreach my $trdrID ( sort { $a <=> $b } keys %{ $feeBySubProd{ $sym }{ $po } } ) {
				my $trdrIDFee = $netFeeByTrdrID{ $trdrID };
				next if $trdrIDFee <= 0;
				
				my $trdrIdPosFee = $netPosFeeByTrdrID{ $trdrID };
				my $trdrIdAdjFee = $adjNetFee * $trdrIDFee / $totPosTrdrIDFee;
				
				foreach my $subProd ( keys %{ $feeBySubProd{ $sym }{ $po }{ $trdrID } } ) {
					my $subProdMap = $feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd };
					my $calcNetFee = $$subProdMap{ CALC_NET };
					if ( $calcNetFee > 0 ) {
						$calcNetFee -= $trdrIdAdjFee * $calcNetFee / $trdrIdPosFee;
						print STDERR "...[$trdrID] [$totCalcNetFee] [$trdrIDFee] [$trdrIdPosFee] [$trdrIdAdjFee] $subProd] $$subProdMap{ CALC_NET } -> $calcNetFee\n";
						$$subProdMap{ CALC_NET } = $calcNetFee;
						
					}
				}
			}
		}
	}
	
#	Compare calculated net fees with those reported in the TDRSALESUM file.
#	-----------------------------------------------------------------------
	foreach my $po ( sort { $a <=> $b } keys %{ $feeBySymPO{ $sym } } ) {
		foreach my $trdrID ( sort { $a <=> $b } keys %{ $feeBySubProd{ $sym }{ $po } } ) {
			foreach my $subProd ( sort keys %{ $feeBySubProd{ $sym }{ $po }{ $trdrID } } ) {
				my $subProdMap = $feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd };
				my $baseFee = $$subProdMap{ BASE };
				my $actualNetFee = $$subProdMap{ NET };
				my $calcNetFee = $$subProdMap{ CALC_NET };
				if ( abs ( $actualNetFee - $calcNetFee ) > 0.011 ) {
					printf STDERR "$sym,$intl,$tier,$po,$trdrID,$subProd,$volBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd }{ ACT },%.2f,%.2f,%.2f\n" , 
							$baseFee , $actualNetFee , $calcNetFee;
				}
			}
		}
	}
}

# Patch the net fees back into the TDRSALESUM file.
# -------------------------------------------------
open ( TDRS , $ARGV[ 1 ] ) or die ( "Cannot open Tdrsalesum file [$ARGV[ 1 ]] : $!" );

$_ = <TDRS>;	# --- print header ---
print;
while ( <TDRS> ) {
	chomp ; s/"//g;
	
	my @flds = split /,/;
	my ( $po , $trdrID , $sym , $subProd ) = @flds[ 0 , 1 , 3 , 4 ];
	my $subProdMap = $feeBySubProd{ $sym }{ $po }{ $trdrID }{ $subProd };
	if ( !$subProdMap ) {
		print "$_\n";
		next;
	}
	$flds[ 11 ] = $$subProdMap{ CALC_NET };
	print join ( "," , @flds ) , "\n";
}

