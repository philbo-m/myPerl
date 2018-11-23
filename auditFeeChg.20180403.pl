#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::SymbolSumm;
use Billing::FeeConv;

sub printRec {
	my ( $key , $v1 , $v2 ) = @_;
	if ( $v1 =~ /^[-\d.]*$/ ) {
		$v1 = sprintf ( "%.2f" , $v1 );
	}
	if ( $v2 =~ /^[-\d.]*$/ ) {
		$v2 = sprintf ( "%.2f" , $v2 );
	}
	print "$key,$v1,$v2\n";
}

sub valMatch { 
	my ( $v1 , $v2 ) = @_;

	return ( abs ( $v1 - $v2 ) < 0.10 );
	if ( abs ( $v1 ) < 0.05 || abs ( $v2 ) < 0.05 ) {
		return ( abs ( $v1 - $v2 ) < 0.10 );
	}
	else {
		return ( abs ( ( $v1 - $v2 ) / ( $v1 + $v2 ) ) < 0.005 );
	}
}

sub patchActPsvFees {
	my ( $feeMap , $oldNew ) = @_;

#	Hack for subproducts whose Passive/Active fees don't appear in the Account Summ file.
#	-------------------------------------------------------------------------------------
	foreach my $sym ( keys %$feeMap ) {
		foreach my $subProd ( sort keys %{ $$feeMap{ $sym } } ) {
		
#			Bypass the fee cap on NEX trades.
#			---------------------------------
			if ( $subProd =~ /^NEX/ ) {
				$$feeMap{ $sym }{ $subProd }{ 'BASIC_FEE' } = $$feeMap{ $sym }{ $subProd }{ 'TOTAL_VOLUME' } 
														* $FeeConv::feeMap{ $oldNew }{ $subProd }{ 'ACT' };
				$$feeMap{ $sym }{ $subProd }{ 'NET_FEE' } = $$feeMap{ $sym }{ $subProd }{ 'BASIC_FEE' } ;
			}
			
			if ( exists $FeeConv::noActPsvFeeProds{ $subProd } ) {
				$$feeMap{ $sym }{ $subProd }{ 'ACTIVE_FEE' } = $$feeMap{ $sym }{ $subProd }{ 'BASIC_FEE' };
				$$feeMap{ $sym }{ $subProd }{ 'PASSIVE_CREDIT' } = 0;
			}
		}
	}
}

# --- NOTE - RT/Warrant awareness hacked in for Q1 2017 UAT ---
sub isRTWT {
	my ( $sym ) = @_;
	return ( $sym =~ /\.[RW]T/ || $sym eq 'QSP.UN' || $sym eq 'ITX' );
}

sub collapse {
	my ( $feeMap , $valKeys , $noFeeValKeys , $oldNew , $rtwt ) = @_;
	
	my $rateMap = $FeeConv::rateMap{ $oldNew };
# 	my $collapseMap = $FeeConv::collapseMap{ $oldNew };
	my $collapseMap = ( $rtwt ? $FeeConv::rtwtCollapseMap{ $oldNew } : $FeeConv::collapseMap );
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %$collapseMap ) {
		foreach my $subProd ( @{ $$collapseMap{ $baseSubProd } } ) {
			$revCollapseMap{ $subProd } = $baseSubProd;
		}
	}

	foreach my $sym ( sort keys %$feeMap ) {
	
		next if ( $rtwt && !isRTWT ( $sym ) );
		
		foreach my $subProd ( keys %{ $$feeMap{ $sym } } ) {
			my $baseSubProd = $revCollapseMap{ $subProd };
			next if !$baseSubProd;
			print STDERR "[$sym] [$subProd] collapsing to [$baseSubProd]...\n";

			my $baseRates = $$rateMap{ $baseSubProd };

			if ( !$baseRates ) {	
			
#				No rate difference between subproducts and "base" subproduct.
#				Just apply all values to the collapse target verbatim.
#				-------------------------------------------------------------
				foreach ( @$valKeys ) {
					$$feeMap{ $sym }{ $baseSubProd }{ $_ } += $$feeMap{ $sym }{ $subProd }{ $_ };
				}
			}
			else {
			
#				Rate does differ between subproducts and "base" subproduct.
#				Transform the fee, and possibly cap, values before applying to collapse target.
#				-------------------------------------------------------------------------------		
				my ( $vol , $psvVol );
				foreach ( @$noFeeValKeys ) {
					my $val = $$feeMap{ $sym }{ $subProd }{ $_ };
					$vol = $val if $_ eq 'TOTAL_VOLUME';
					$psvVol = $val if $_ eq 'PASSIVE_VOLUME';
					if ( $_ eq 'VOL <= CAP' && $val ) {
						$vol = $val;
						$psvVol = 0;
					}
					if ( $_ eq 'CAPPED_TRADES' && $val ) {
						$vol += $val * $$baseRates{ CAP } / $$baseRates{ ACT };
					}
					$$feeMap{ $sym }{ $baseSubProd }{ $_ } += $val;
				}
				
				my $basePsvCrd = $psvVol * $$baseRates{ PSV };
				my $baseActFee = ( $vol - $psvVol ) * $$baseRates{ ACT };

#				print STDERR "[$sym] : collapsing subprod [$subProd] [$vol] [$psvVol] [$baseActFee] [$basePsvCrd] into base [$baseSubProd]...\n";
				$$feeMap{ $sym }{ $baseSubProd }{ ACTIVE_FEE } += $baseActFee;
				$$feeMap{ $sym }{ $baseSubProd }{ PASSIVE_CREDIT } += $basePsvCrd;
				$$feeMap{ $sym }{ $baseSubProd }{ BASIC_FEE } += $baseActFee + $basePsvCrd;
				$$feeMap{ $sym }{ $baseSubProd }{ NET_FEE } += $baseActFee + $basePsvCrd;
			}
			
			delete $$feeMap{ $sym }{ $subProd };
		}
	}
}

sub undoTrdCaps {
	my ( $feeMap , $from ) = @_;
	
	foreach my $sym ( sort keys %$feeMap ) {
		foreach my $subProd ( sort keys %{ $$feeMap{ $sym } } ) {

			my $myMap = $$feeMap{ $sym }{ $subProd };
			
#			--- If no capped trades, then nothing to do. ---		
			my $cappedTrds = $$myMap{ CAPPED_TRADES };
			next if !$cappedTrds;
			
			my $oldRates = $FeeConv::rateMap{ OLD }{ $subProd };
			next if !$oldRates;
			my $newRates = $FeeConv::rateMap{ NEW }{ $subProd };
			next if !$newRates;
#			print STDERR "[$from] [$sym] [$subProd]...\n";
#			print STDERR "OLD RATES [" , Dumper ( $oldRates ) , "]\n";
#			print STDERR "NEW RATES [" , Dumper ( $newRates ) , "]\n";
			
#			Only need to do this if the rates or cap are changing.
#			Note - subproducts with trade caps have ACTIVE volume only.
#			-----------------------------------------------------------
			next if ( !$$oldRates{ CAP } || !$$newRates{ CAP } );
			next if ( $$oldRates{ CAP } == $$newRates{ CAP } 
						&& $$oldRates{ ACT } == $$newRates{ ACT } );
			
			my $myRates = ( $from eq 'OLD' ? $oldRates : $newRates );

#			print STDERR "[$from] [$sym] [$subProd] undoing [" , Dumper ( $myMap ) , "]\n";
			$$myMap{ CAPPED_TRADES } = 0;
			$$myMap{ 'VOL <= CAP' } = $$myMap{ TOTAL_VOLUME };
			$$myMap{ ACTIVE_FEE } = ( $$myMap{ TOTAL_VOLUME } - $$myMap{ PASSIVE_VOLUME } ) 
										* $$myRates{ 'ACT' }; 
			$$myMap{ BASIC_FEE } = $$myMap{ ACTIVE_FEE } + $$myMap{ PASSIVE_CREDIT };
			$$myMap{ NET_FEE } = $$myMap{ BASIC_FEE };
#			print STDERR "...to [" , Dumper ( $myMap ) , "]\n";
		}
	}
}

sub transform {
	my ( $feeMap , $from ) = @_;
	my $to = ( $from eq 'OLD' ? 'NEW' : 'OLD' );
	
	foreach my $sym ( keys %$feeMap ) {
		foreach my $subProd ( sort keys %{ $$feeMap{ $sym } } ) {

			next if ( !exists $FeeConv::rateMap{ $from }{ $subProd } );

			my $origRates = $FeeConv::rateMap{ $from }{ $subProd };
			my $chgRates = $FeeConv::rateMap{ $to }{ $subProd };
			
			my $actFee = $$feeMap{ $sym }{ $subProd }{ 'ACTIVE_FEE' };
			my $psvCrd = $$feeMap{ $sym }{ $subProd }{ 'PASSIVE_CREDIT' };
#			print STDERR "Transforming [$sym] [$subProd] [$actFee] [$psvCrd]...\n";
		
			if ( exists $$origRates{ 'ACT' } && $$origRates{ 'ACT' } != $$chgRates{ 'ACT' } ) {
#				print STDERR "[$sym] [$subProd] ACT [$$origRates{ 'ACT' }] -> [$$chgRates{ 'ACT' }]\n";
				$actFee *= $$chgRates{ 'ACT' } / $$origRates{ 'ACT' };
			}
			if ( exists $$origRates{ 'PSV' } && $$origRates{ 'PSV' } != $$chgRates{ 'PSV' } ) {
#				print STDERR "[$sym] [$subProd] PSV [$$origRates{ 'PSV' }] -> [$$chgRates{ 'PSV' }]\n";
				$psvCrd *= $$chgRates{ 'PSV' } / $$origRates{ 'PSV' };
			}
		
#			print STDERR "[$sym] : Converting $from [$subProd] fee to $to [$actFee] [$psvCrd] [" , $actFee + $psvCrd , "]\n";
			$$feeMap{ $sym }{ $subProd }{ 'ACTIVE_FEE' } = $actFee;
			$$feeMap{ $sym }{ $subProd }{ 'PASSIVE_CREDIT' } = $psvCrd;		
			$$feeMap{ $sym }{ $subProd }{ 'BASIC_FEE' } = $actFee + $psvCrd;
			$$feeMap{ $sym }{ $subProd }{ 'NET_FEE' } = $actFee + $psvCrd;	# --- this will be incorrect for some MOO and some RT ---
		}
	}
}

sub applyRelocatedVals {
	my ( $oldFeeMap , $relocatedFeeMap , $valKeys ) = @_;
	
	foreach my $sym ( keys %$relocatedFeeMap ) {
		foreach my $subProd ( keys %{ $$relocatedFeeMap{ $sym } } ) {
			foreach my $valKey ( @$valKeys ) {
#				print STDERR "Adding [$$relocatedFeeMap{ $subProd }{ $valKey }] to old fee map [$sym] [$subProd] [$valKey]...\n";
				$$oldFeeMap{ $sym }{ $subProd }{ $valKey } += $$relocatedFeeMap{ $sym }{ $subProd }{ $valKey };
			}
		}
	}
}

sub correctRTNetFees {
	my ( $feeMap , $symList ) = @_;
	
	foreach my $sym ( @$symList ) {
		my $totBasicFee = 0;
		foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/ } keys %{ $$feeMap{ $sym } } ) {
			my $prodFeeMap = $$feeMap{ $sym }{ $rtSubProd };
			$totBasicFee += $$prodFeeMap{ BASIC_FEE };
		}
		next if $totBasicFee <= 0;
		$totBasicFee = 1000 if $totBasicFee > 1000;
		
#		print "[$sym] RT fees too high by [$totBasicFee]...\n";

		foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/ } keys %{ $$feeMap{ $sym } } ) {
			my $prodFeeMap = $$feeMap{ $sym }{ $rtSubProd };
			my $totFeeMap = $$feeMap{ TOTAL }{ $rtSubProd };
			my $basicFee = $$prodFeeMap{ BASIC_FEE };
			if ( $basicFee > 0 ) {
				my $origNetFee = $$prodFeeMap{ NET_FEE };
				my $feeDiff = ( $basicFee < $totBasicFee ? $basicFee : $totBasicFee );
#				print "...[$sym] [$rtSubProd] reducing net fee from [$origNetFee] to [" , $basicFee - $feeDiff , "]...\n";
				$$prodFeeMap{ NET_FEE } = $basicFee - $feeDiff;
				$$totFeeMap{ NET_FEE } -= ( $origNetFee - ( $basicFee - $feeDiff ) );
				$totBasicFee -= $feeDiff;
				last if $totBasicFee == 0;
			}
		}
	}
}
	
# ===================================================================================================	
	
my $oldFile = new SymbolSumm (
					file	=> $ARGV[ 0 ]
				);
		
my $newFile = new SymbolSumm (
					file	=> $ARGV[ 1 ]
				);

my @noFeeValKeys = ( "TOTAL_VOLUME" , "PASSIVE_VOLUME" , "VOL <= CAP" , "CAPPED_TRADES" , "TOTAL_VALUE" , "PASSIVE_VALUE" , "TOTAL_TRADES" , "PASSIVE_TRADES" );
my @valKeys = ( @noFeeValKeys , qw ( ACTIVE_FEE PASSIVE_CREDIT BASIC_FEE NET_FEE ) );

# Get symbols participating in subproducts being toasted.
# -------------------------------------------------------
my %toastSymMap;

foreach my $subProd ( sort keys %FeeConv::toastMap ) {
	foreach my $sym ( @{ $oldFile->keys ( 'SYMBOL' ) } ) {
		if ( !exists $toastSymMap{ $sym } 
				&& $oldFile->val ( { SYMBOL => $sym , PRODUCT => $subProd } , 'TOTAL_VOLUME' ) ) {
			$toastSymMap{ $sym } = 1;
		}
	}
} 

# Get old volumes + fees by symbol on subproducts being toasted, and new volumes/fees
# on the corresponding new subproducts they might be contributing to.
# -----------------------------------------------------------------------------------
my %relocatedFeeMap;

foreach my $sym ( sort keys %toastSymMap ) {
	foreach my $subProd ( sort keys %FeeConv::toastMap ) {
		my %keyMap = ( SYMBOL => $sym , PRODUCT => $subProd );
		next if !$oldFile->val ( \%keyMap , 'TOTAL_VOLUME' );
		print "$sym,OLD,$subProd";
		foreach my $valKey ( @valKeys ) {
			print "," , $oldFile->val ( \%keyMap , $valKey );
		}
		print "\n";
	}
	print "$sym,OLD,TOTAL";
	foreach my $valKey ( @valKeys ) {
		print "," , $oldFile->val ( { SYMBOL => $sym } , $valKey );
	}
	print "\n";
	
	foreach my $subProd ( sort @{ $newFile->keys ( 'PRODUCT' ) } ) {
		my %keyMap = ( SYMBOL => $sym , PRODUCT => $subProd );
		next if !$newFile->val ( \%keyMap , 'TOTAL_VOLUME' );
		print "$sym,NEW,$subProd";
		foreach my $valKey ( @valKeys ) {
			my $val = $newFile->val ( \%keyMap , $valKey );
			print "," , $val;
			$relocatedFeeMap{ $sym }{ $subProd }{ $valKey } = $val;
		}
		print "\n";
	}
	print "$sym,NEW,TOTAL";
	foreach my $valKey ( @valKeys ) {
		print "," , $newFile->val ( { SYMBOL => $sym } , $valKey );
	}
	print "\n";
	
	print "$sym,DIFF,TOTAL";
	foreach my $valKey ( @valKeys ) {
		print "," , $newFile->val ( { SYMBOL => $sym } , $valKey ) 
						- $oldFile->val ( { SYMBOL => $sym } , $valKey );
	}
	print "\n";
}

foreach my $subProd ( sort keys %relocatedFeeMap ) {
	print "$subProd,RELOCATED";
	foreach my $valKey ( @valKeys ) {
		print "," , $relocatedFeeMap{ $subProd }{ $valKey };
	}
	print "\n";
}

print "\n";
		
# Cache the values in the files - as we will need to transform them.
# ------------------------------------------------------------------
my ( %oldFeeMap , %newFeeMap );
my $symList = $oldFile->keys ( 'SYMBOL' );

foreach my $subProd ( @{ $oldFile->keys ( 'PRODUCT' ) } ) {
	foreach my $sym ( @$symList ) {
		next if !( $oldFile->val ( { SYMBOL => $sym , PRODUCT => $subProd } , 'TOTAL_VOLUME' ) );
		foreach my $valKey ( @valKeys ) {
			my $val = $oldFile->val ( { PRODUCT => $subProd , SYMBOL => $sym } , $valKey );
			foreach ( "TOTAL" , $sym ) {
				$oldFeeMap{ $_ }{ $subProd }{ $valKey } += $val;
			}
		}
	}
}

foreach my $subProd ( @{ $newFile->keys ( 'PRODUCT' ) } ) {
	foreach my $sym ( @$symList ) {
		next if !( $newFile->val ( { SYMBOL => $sym , PRODUCT => $subProd } , 'TOTAL_VOLUME' ) );
		foreach my $valKey ( @valKeys ) {
			my $val = $newFile->val ( { PRODUCT => $subProd , SYMBOL => $sym } , $valKey );
			foreach ( "TOTAL" , $sym ) {
				$newFeeMap{ $_ }{ $subProd }{ $valKey } += $val;
			}
		}
	}
}

# Patch problematic subproducts (with zero Active Fee/Passive Credit fields).
# ---------------------------------------------------------------------------
patchActPsvFees ( \%oldFeeMap , 'OLD' );
patchActPsvFees ( \%newFeeMap , 'NEW' );
patchActPsvFees ( \%relocatedFeeMap , 'NEW' );

# Undo any capped subproducts whose fee or cap might be changing.
# ---------------------------------------------------------------
undoTrdCaps ( \%oldFeeMap , 'OLD' );
undoTrdCaps ( \%newFeeMap , 'NEW' );

# Make fee adjustments in old file.
# ---------------------------------
transform ( \%oldFeeMap , 'OLD' );

# Collapse the new subproducts in the new file.
# ---------------------------------------------
collapse ( \%newFeeMap , \@valKeys , \@noFeeValKeys , 'NEW' );

# Collapse the RT/Warrant subproducts (Q1 2018 ONLY)
# --------------------------------------------------
collapse ( \%newFeeMap , \@valKeys , \@noFeeValKeys , 'NEW' , 1 );

# Apply the re-allocated subproducts.
# -----------------------------------
applyRelocatedVals ( \%oldFeeMap , \%relocatedFeeMap , \@valKeys );

# Calculate RT net fees, for cases where a symbol has a total positive RT fee.
# ----------------------------------------------------------------------------
correctRTNetFees ( \%oldFeeMap , $symList );

foreach my $subProd ( sort keys %{ $oldFeeMap{ "TOTAL" } } ) {
	next if exists $FeeConv::toastMap{ $subProd };
	if ( !$newFeeMap{ "TOTAL" }{ $subProd }{ 'TOTAL_VOLUME' } ) {
		print "$subProd,OLD_ONLY";
		foreach my $valKey ( @valKeys ) {
			print "," , $oldFeeMap{ "TOTAL" }{ $subProd }{ $valKey };
		}
		print "\n";
	}
	
	foreach my $valKey ( @valKeys ) {
		my $oldVal = $oldFeeMap{ "TOTAL" }{ $subProd }{ $valKey };
		my $newVal = $newFeeMap{ "TOTAL" }{ $subProd }{ $valKey };
#		print "COMPARING $subProd $valKey $oldVal $newVal...\n";
		if ( !valMatch ( $oldVal , $newVal ) ) {
			print "$subProd,DIFF,$valKey,$oldVal,$newVal," , $newVal - $oldVal , "\n";
		}
	}
}

foreach my $subProd ( sort keys %{ $newFeeMap{ "TOTAL" } } ) {
	next if $oldFeeMap{ "TOTAL" }{ $subProd }{ 'TOTAL_VOLUME' };
	print "$subProd,NEW_ONLY";
	foreach my $valKey ( @valKeys ) {
		print "," , $newFeeMap{ "TOTAL" }{ $subProd }{ $valKey };
	}
	print "\n";
}


__DATA__
foreach my $subProd ( sort keys %oldFeeMap ) {
	next if exists $FeeConv::toastMap{ $subProd }
	if ( !exists $newFeeMap{ $subProd } ) {
		printRec ( $subProd , $oldFeeMap{ $subProd }{ 'FEE' } , "N/A" );
		next;
	}
	if ( !valMatch ( $oldFeeMap{ $subProd }{ 'FEE' } , $newFeeMap{ $subProd }{ 'FEE' } ) ) {
		printRec ( $subProd , $oldFeeMap{ $subProd }{ 'FEE' } , $newFeeMap{ $subProd }{ 'FEE' } );
	}
	
}

foreach my $subProd ( sort keys %newFeeMap ) {
	if ( !exists $oldFeeMap{ $subProd } ) {
		printRec ( $subProd , "N/A" , $newFeeMap{ $subProd }{ 'FEE' } );
	}
}
