#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::SymbolSumm;
use Billing::FeeConv;

my $DEBUG = 1;

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

sub dbg {
	if ( $DEBUG ) {
		print STDERR join ( " " , @_ ) , "\n";
	}
}

sub patchActPsvFees {
	my ( $feeMap , $oldNew ) = @_;

#	Hack for subproducts whose Passive/Active fees don't appear in the Account Summ file.
#	-------------------------------------------------------------------------------------
	foreach my $sym ( keys %$feeMap ) {
		foreach my $acctType ( sort keys %{ $$feeMap{ $sym } } ) {
			foreach my $subProd ( sort keys %{ $$feeMap{ $sym }{ $acctType } } ) {
		
				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $subProd };
				
#				Bypass the fee cap on NEX trades.
#				---------------------------------
				if ( $subProd =~ /^NEX/ ) {
					$$feeNode{ 'BASIC_FEE' } = $$feeNode{ 'TOTAL_VOLUME' } 
												* $FeeConv::feeMap{ $oldNew }{ $subProd }{ 'ACT' };
					$$feeNode{ 'NET_FEE' } = $$feeNode{ 'BASIC_FEE' } ;
				}
			
				if ( exists $FeeConv::noActPsvFeeProds{ $subProd } ) {
					$$feeNode{ 'ACTIVE_FEE' } = $$feeNode{ 'BASIC_FEE' };
					$$feeNode{ 'PASSIVE_CREDIT' } = 0;
				}
			}
		}
	}
}

sub getIntlSyms {
	my ( $feeMap ) = @_;
	
	my @symList = ();
	foreach my $sym ( keys %$feeMap ) {
		my $isIntl = 0;
		foreach my $acctType ( keys %{ $$feeMap{ $sym } } ) {
			last if $isIntl;
			foreach my $subProd ( keys %{ $$feeMap{ $sym }{ $acctType } } ) {
				if ( $subProd =~ /_INTL/ ) {
					push @symList , $sym;
					last;
				}
			}
		}
	}
	
	return \@symList;
}
	
sub collapse {
	my ( $feeMap , $valKeys , $noFeeValKeys , $oldNew , $what , $intlSymList ) = @_;
	
	my $rateMap = $FeeConv::rateMap{ $oldNew };
	my $collapseMap = $FeeConv::collapseMap{ $oldNew };
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %$collapseMap ) {
		foreach my $subProd ( @{ $$collapseMap{ $baseSubProd } } ) {
			$revCollapseMap{ $subProd } = $baseSubProd;
		}
	}
# 	dbg ( "[$what] :\n" , Dumper ( \%revCollapseMap ) , "\n" );

	my %intlSymMap = ();
	%intlSymMap = map { $_ => 1 } @$intlSymList if $intlSymList;
	
	foreach my $sym ( grep { $_ ne 'TOTAL' } sort keys %$feeMap ) {

		foreach my $acctType ( keys %{ $$feeMap{ $sym } } ) {
		
			foreach my $subProd ( keys %{ $$feeMap{ $sym }{ $acctType } } ) {
				my $baseSubProd = $revCollapseMap{ $subProd };
				next if !$baseSubProd;

				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $subProd };
				my $totFeeNode = $$feeMap{ TOTAL }{ $acctType }{ $subProd };
				
				if ( $baseSubProd =~ /LO_DARK_DARK/ ) {
				
#					--- base subproduct needs to be split into T1 or T2 ---
					my $avgPrc = $$feeNode{ 'TOTAL_VALUE' } / $$feeNode{ 'TOTAL_VOLUME' };
					$baseSubProd .= ( $avgPrc < 0.10 ? '_T1' : '_T2' );
				}
				
				dbg ( "[$sym] [$acctType] [$subProd] collapsing to [$baseSubProd]..." );

				if ( !exists $$feeMap{ $sym }{ $acctType }{ $baseSubProd } ) {
					$$feeMap{ $sym }{ $acctType }{ $baseSubProd } = {};
				}
				my $baseFeeNode = $$feeMap{ $sym }{ $acctType }{ $baseSubProd };
				if ( !exists $$feeMap{ TOTAL }{ $acctType }{ $baseSubProd } ) {
					$$feeMap{ TOTAL }{ $acctType }{ $baseSubProd } = {};
				}
				my $baseTotFeeNode = $$feeMap{ TOTAL }{ $acctType }{ $baseSubProd };
				
				my $baseRates = $$rateMap{ $baseSubProd };

				if ( !$baseRates ) {	
				
#					No rate difference between subproducts and "base" subproduct.
#					Just apply all values to the collapse target verbatim.
#					-------------------------------------------------------------
					foreach ( @$valKeys ) {
						$$baseFeeNode{ $_ } += $$feeNode{ $_ };
						$$baseTotFeeNode{ $_ } += $$feeNode{ $_ };
						$$totFeeNode{ $_ } -= $$feeNode{ $_ };
					}
				}
				else {
				
#					Rate does differ between subproducts and "base" subproduct.
#					Transform the fee, and possibly cap, values before applying to collapse target.
#					-------------------------------------------------------------------------------	
					my ( $vol , $psvVol );
					foreach ( @$noFeeValKeys ) {
						my $val = $$feeNode{ $_ };
						$vol = $val if $_ eq 'TOTAL_VOLUME';
						$psvVol = $val if $_ eq 'PASSIVE_VOLUME';
						if ( $_ eq 'VOL <= CAP' && $val ) {
							$vol = $val;
							$psvVol = 0;
						}
						if ( $_ eq 'CAPPED_TRADES' && $val ) {
							$vol += $val * $$baseRates{ CAP } / $$baseRates{ ACT };
						}
						$$baseFeeNode{ $_ } += $val;						
						$$baseTotFeeNode{ $_ } += $val;
						$$totFeeNode{ $_ } -= $val;
					}
					
					my $basePsvCrd = $psvVol * $$baseRates{ PSV };
					my $baseActFee = ( $vol - $psvVol ) * $$baseRates{ ACT };

					dbg ( "[$sym] [$acctType] : collapsing subprod [$subProd] [$vol] [$psvVol] [$baseActFee] [$basePsvCrd] into base [$baseSubProd]..." );
					$$baseFeeNode{ ACTIVE_FEE } += $baseActFee;
					$$baseFeeNode{ PASSIVE_CREDIT } += $basePsvCrd;
					$$baseFeeNode{ BASIC_FEE } += $baseActFee + $basePsvCrd;
					$$baseFeeNode{ NET_FEE } += $baseActFee + $basePsvCrd;

					$$baseTotFeeNode{ ACTIVE_FEE } += $baseActFee;
					$$baseTotFeeNode{ PASSIVE_CREDIT } += $basePsvCrd;
					$$baseTotFeeNode{ BASIC_FEE } += $baseActFee + $basePsvCrd;
					$$baseTotFeeNode{ NET_FEE } += $baseActFee + $basePsvCrd;
					$$totFeeNode{ ACTIVE_FEE } -= $$feeNode{ ACTIVE_FEE };
					$$totFeeNode{ PASSIVE_CREDIT } -= $$feeNode{ PASSIVE_CREDIT };
					$$totFeeNode{ BASIC_FEE } -= $$feeNode{ BASIC_FEE };
					$$totFeeNode{ NET_FEE } -= $$feeNode{ NET_FEE };;
				}
				
				if ( !$$feeMap{ "TOTAL" }{ $acctType }{ $subProd }{ TOTAL_VOLUME } ) {
					delete $$feeMap{ "TOTAL" }{ $acctType }{ $subProd };
				}
				delete $$feeMap{ $sym }{ $acctType }{ $subProd };
			}
		}
	}
}

sub undoTrdCaps {
	my ( $feeMap , $from ) = @_;
	
	foreach my $sym ( sort keys %$feeMap ) {
		foreach my $acctType ( sort keys %{ $$feeMap{ $sym } } ) {
			foreach my $subProd ( sort keys %{ $$feeMap{ $sym }{ $acctType } } ) {

				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $subProd };
			
#				--- If no capped trades, then nothing to do. ---		
				my $cappedTrds = $$feeNode{ CAPPED_TRADES };
				next if !$cappedTrds;
				
				my $oldRates = $FeeConv::rateMap{ OLD }{ $subProd };
				next if !$oldRates;
				my $newRates = $FeeConv::rateMap{ NEW }{ $subProd };
				next if !$newRates;
#				dbg ( "[$from] [$sym] [$subProd]..." );
#				dbg ( "OLD RATES [" , Dumper ( $oldRates ) , "]" );
#				dbg ( "NEW RATES [" , Dumper ( $newRates ) , "]" );
			
#				Only need to do this if the rates or cap are changing.
#				Note - subproducts with trade caps have ACTIVE volume only.
#				-----------------------------------------------------------
				next if ( !$$oldRates{ CAP } || !$$newRates{ CAP } );
				next if ( $$oldRates{ CAP } == $$newRates{ CAP } 
							&& $$oldRates{ ACT } == $$newRates{ ACT } );
				
				my $myRates = ( $from eq 'OLD' ? $oldRates : $newRates );

#				dbg ( "[$from] [$sym] [$subProd] undoing [" , Dumper ( $feeNode ) , "]" );
				$$feeNode{ CAPPED_TRADES } = 0;
				$$feeNode{ 'VOL <= CAP' } = $$feeNode{ TOTAL_VOLUME };
				$$feeNode{ ACTIVE_FEE } = ( $$feeNode{ TOTAL_VOLUME } - $$feeNode{ PASSIVE_VOLUME } ) 
											* $$myRates{ 'ACT' }; 
				$$feeNode{ BASIC_FEE } = $$feeNode{ ACTIVE_FEE } + $$feeNode{ PASSIVE_CREDIT };
				$$feeNode{ NET_FEE } = $$feeNode{ BASIC_FEE };
#				dbg ( "...to [" , Dumper ( $feeNode ) , "]" );
			}
		}
	}
}

sub transform {
	my ( $feeMap , $from ) = @_;
	my $to = ( $from eq 'OLD' ? 'NEW' : 'OLD' );
	
	foreach my $sym ( keys %$feeMap ) {
		foreach my $acctType ( sort keys %{ $$feeMap{ $sym } } ) {
			foreach my $subProd ( sort keys %{ $$feeMap{ $sym }{ $acctType } } ) {

				next if ( !exists $FeeConv::rateMap{ $from }{ $subProd } );

				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $subProd };

				my $origRates = $FeeConv::rateMap{ $from }{ $subProd };
				my $chgRates = $FeeConv::rateMap{ $to }{ $subProd };

				my $actFee = $$feeNode{ 'ACTIVE_FEE' };
				my $psvCrd = $$feeNode{ 'PASSIVE_CREDIT' };
#				dbg ( "Transforming [$sym] [$acctType] [$subProd] [$actFee] [$psvCrd]..." );
		
				if ( exists $$origRates{ 'ACT' } && $$origRates{ 'ACT' } != $$chgRates{ 'ACT' } ) {
#					dbg ( "[$sym] [$acctType] [$subProd] ACT [$$origRates{ 'ACT' }] -> [$$chgRates{ 'ACT' }]" );
					$actFee *= $$chgRates{ 'ACT' } / $$origRates{ 'ACT' };
				}
				if ( exists $$origRates{ 'PSV' } && $$origRates{ 'PSV' } != $$chgRates{ 'PSV' } ) {
#					dbg ( "[$sym] [$acctType] [$subProd] PSV [$$origRates{ 'PSV' }] -> [$$chgRates{ 'PSV' }]" );
					$psvCrd *= $$chgRates{ 'PSV' } / $$origRates{ 'PSV' };
				}
		
				dbg ( "[$sym] [$acctType] : Converting $from [$subProd] fee to $to [$actFee] [$psvCrd] [" , $actFee + $psvCrd , "]" );
				$$feeNode{ 'ACTIVE_FEE' } = $actFee;
				$$feeNode{ 'PASSIVE_CREDIT' } = $psvCrd;		
				$$feeNode{ 'BASIC_FEE' } = $actFee + $psvCrd;
				$$feeNode{ 'NET_FEE' } = $actFee + $psvCrd;	# --- this will be incorrect for some MOO and some RT ---
			}
		}
	}
}

sub applyRelocatedVals {
	my ( $oldFeeMap , $relocatedFeeMap , $valKeys ) = @_;
	
	foreach my $sym ( keys %$relocatedFeeMap ) {
		foreach my $acctType ( keys %{ $$relocatedFeeMap{ $sym } } ) {
			foreach my $subProd ( keys %{ $$relocatedFeeMap{ $sym }{ $acctType } } ) {
			
				my $oldFeeNode = $$oldFeeMap{ $sym }{ $acctType }{ $subProd };
				my $relocFeeNode = $$relocatedFeeMap{ $sym }{ $acctType }{ $subProd };
				
				foreach my $valKey ( @$valKeys ) {
					$$oldFeeNode{ $valKey } += $$relocFeeNode{ $valKey };
				}
			}
		}
	}
}

sub correctRTNetFees {
	my ( $feeMap , $symList ) = @_;
	
	foreach my $sym ( @$symList ) {
		my $totBasicFee = 0;
		foreach my $acctType ( keys %{ $$feeMap{ $sym } } ) {
			foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/ } keys %{ $$feeMap{ $sym }{ $acctType } } ) {
				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $rtSubProd };
				$totBasicFee += $$feeNode{ BASIC_FEE };
			}
		}
		next if $totBasicFee <= 0;
		$totBasicFee = 1000 if $totBasicFee > 1000;
		
#		print "[$sym] RT fees too high by [$totBasicFee]...\n";

		
		foreach my $acctType ( keys %{ $$feeMap{ $sym } } ) {
			foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/ } keys %{ $$feeMap{ $sym }{ $acctType } } ) {
				my $feeNode = $$feeMap{ $sym }{ $acctType }{ $rtSubProd };
				my $totFeeNode = $$feeMap{ TOTAL }{ $acctType }{ $rtSubProd };
				my $basicFee = $$feeNode{ BASIC_FEE };
				if ( $basicFee > 0 ) {
					my $origNetFee = $$feeNode{ NET_FEE };
					my $feeDiff = ( $basicFee < $totBasicFee ? $basicFee : $totBasicFee );
#					print "...[$sym] [$acctType] [$rtSubProd] reducing net fee from [$origNetFee] to [" , $basicFee - $feeDiff , "]...\n";
					$$feeNode{ NET_FEE } = $basicFee - $feeDiff;
					$$totFeeNode{ NET_FEE } -= ( $origNetFee - ( $basicFee - $feeDiff ) );
					$totBasicFee -= $feeDiff;
					last if $totBasicFee == 0;
				}
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

foreach my $acctType ( @{ $oldFile->keys ( 'ACCT_TYPE' ) } ) {
	foreach my $subProd ( @{ $oldFile->keys ( 'PRODUCT' ) } ) {
		foreach my $sym ( @$symList ) {
			next if !( $oldFile->val ( { ACCT_TYPE => $acctType , SYMBOL => $sym , PRODUCT => $subProd } , 'TOTAL_VOLUME' ) );
			foreach my $valKey ( @valKeys ) {
				my $val = $oldFile->val ( { ACCT_TYPE => $acctType , PRODUCT => $subProd , SYMBOL => $sym } , $valKey );
				foreach ( "TOTAL" , $sym ) {
					$oldFeeMap{ $_ }{ $acctType }{ $subProd }{ $valKey } += $val;
				}
			}
		}
	}
}

foreach my $acctType ( @{ $oldFile->keys ( 'ACCT_TYPE' ) } ) {
	foreach my $subProd ( @{ $newFile->keys ( 'PRODUCT' ) } ) {
		foreach my $sym ( @$symList ) {
			next if !( $newFile->val ( { ACCT_TYPE => $acctType , SYMBOL => $sym , PRODUCT => $subProd } , 'TOTAL_VOLUME' ) );
			foreach my $valKey ( @valKeys ) {
				my $val = $newFile->val ( { ACCT_TYPE => $acctType , PRODUCT => $subProd , SYMBOL => $sym } , $valKey );
				foreach ( "TOTAL" , $sym ) {
					$newFeeMap{ $_ }{ $acctType }{ $subProd }{ $valKey } += $val;
				}
			}
		}
	}
}

my %vm = ();
foreach my $sym ( keys %newFeeMap ) {
	foreach my $subProd ( sort keys %{ $newFeeMap{ $sym }{ CLT } } ) {
		my $key = ( $sym eq 'TOTAL' ? $subProd . '_TOTAL' : $subProd );
		$vm{ $key } += $newFeeMap{ $sym }{ CLT }{ $subProd }{ TOTAL_VOLUME };
	}
}
# dbg ( "1 :\n" , join ( "\n" , map { "$_ = $vm{ $_ }" } sort keys %vm ) );

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
%vm = ();
foreach my $sym ( keys %newFeeMap ) {
	foreach my $subProd ( sort keys %{ $newFeeMap{ $sym }{ CLT } } ) {
		my $key = ( $sym eq 'TOTAL' ? $subProd . '_TOTAL' : $subProd );
		$vm{ $key } += $newFeeMap{ $sym }{ CLT }{ $subProd }{ TOTAL_VOLUME };
	}
}
# dbg ( "1a :\n" , join ( "\n" , map { "$_ = $vm{ $_ }" } sort keys %vm ) );

%vm = ();
foreach my $sym ( keys %newFeeMap ) {
	foreach my $subProd ( sort keys %{ $newFeeMap{ $sym }{ CLT } } ) {
		my $key = ( $sym eq 'TOTAL' ? $subProd . '_TOTAL' : $subProd );
		$vm{ $key } += $newFeeMap{ $sym }{ CLT }{ $subProd }{ TOTAL_VOLUME };
	}
}
# dbg ( "2 :\n" , join ( "\n" , map { "$_ = $vm{ $_ }" } sort keys %vm ) );

# Apply the re-allocated subproducts.
# -----------------------------------
applyRelocatedVals ( \%oldFeeMap , \%relocatedFeeMap , \@valKeys );

# Calculate RT net fees, for cases where a symbol has a total positive RT fee.
# ----------------------------------------------------------------------------
correctRTNetFees ( \%oldFeeMap , $symList );

%vm = ();
foreach my $sym ( keys %newFeeMap ) {
	foreach my $subProd ( sort keys %{ $newFeeMap{ $sym }{ CLT } } ) {
		my $key = ( $sym eq 'TOTAL' ? $subProd . '_TOTAL' : $subProd );
		$vm{ $key } += $newFeeMap{ $sym }{ CLT }{ $subProd }{ TOTAL_VOLUME };
	}
}
# dbg ( "3 :\n" , join ( "\n" , map { "$_ = $vm{ $_ }" } sort keys %vm ) );

foreach my $acctType ( sort keys %{ $oldFeeMap{ "TOTAL" } } ) {
	foreach my $subProd ( sort keys %{ $oldFeeMap{ "TOTAL" }{ $acctType } } ) {
		next if exists $FeeConv::toastMap{ $subProd };
		
		if ( !$newFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ 'TOTAL_VOLUME' } ) {
			print "$acctType,$subProd,OLD_ONLY";
			foreach my $valKey ( @valKeys ) {
				print "," , $oldFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ $valKey };
			}
			print "\n";
		}
	
		foreach my $valKey ( @valKeys ) {
			my $oldVal = $oldFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ $valKey };
			my $newVal = $newFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ $valKey };
#			print "COMPARING $acctType $subProd $valKey $oldVal $newVal...\n";
			if ( !valMatch ( $oldVal , $newVal ) ) {
				print "$acctType,$subProd,DIFF,$valKey,$oldVal,$newVal," , $newVal - $oldVal , "\n";
			}
		}
	}
}

foreach my $acctType ( sort keys %{ $newFeeMap{ "TOTAL" } } ) {
	foreach my $subProd ( sort keys %{ $newFeeMap{ "TOTAL" }{ $acctType } } ) {
		next if $oldFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ 'TOTAL_VOLUME' };
		print "$acctType,$subProd,NEW_ONLY";
		foreach my $valKey ( @valKeys ) {
			print "," , $newFeeMap{ "TOTAL" }{ $acctType }{ $subProd }{ $valKey };
		}
		print "\n";
	}
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
