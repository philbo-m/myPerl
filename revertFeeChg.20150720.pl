#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Data::Dumper;

use Billing::SymbolSumm;
use Billing::AccountSumm;
use Billing::TraderDetail;
use Billing::RTSymCredit;
use Billing::FeeConv;

my %nonClobProdMap = ( 
	"TSX Opening Auction" 			=> [ "T_MOO" , "T_MOO_RT" , "T_MOO_CORR" ] ,
	"TSX Venture Opening Auction"	=> [ "V_MOO" , "V_MOO_DEBT" , "V_MOO_CORR" ] ,
	"MBF"							=> [ "T_MBF" ] ,
	"TSX MOC"						=> [ "T_MOC" ] ,
	"TSX Extended Trading"			=> [ "T_EXT" , "T_EXT_CORR" ] ,
	"TSXV MOC"						=> [ "V_MOC" ] ,
	"TSXV Extended Trading"			=> [ "V_EXT" , "V_EXT_CORR" ] ,
	"Settlement Terms"				=> [ "T_ST" ] ,
	"TSX Rights/Warrants"			=> [ "T_RW" , "T_RW_CPF_OPN" , "T_RW_RT" ] ,
	"TSX Notes/Debentures"			=> [ "T_DEBT" ] ,
	"TSX MGF Autofill"				=> [ "T_HI_MGF" , "T_HI_MGF_INTL" , "T_LO_MGF" , "T_HI_MGF_CORR" , "T_LO_MGF_CORR" ,
										"T_HI_OL" , "T_LO_OL" ,
										"T_HI_MOC_AUTOFILL" , "T_LO_MOC_AUTOFILL" ] ,
	"TSXV Oddlot Autofill"			=> [ "V_HI_OL_AUTOFILL" , "V_LO_T1_OL_AUTOFILL" , "V_LO_T2_OL_AUTOFILL" ,
										"V_HI_MOC_AUTOFILL" , "V_LO_T1_MOC_AUTOFILL" , "V_LO_T2_MOC_AUTOFILL" ] ,
	"TSX Exchangeables"				=> [ "T_EXCH" , "T_EXCH_RT" ] ,
	"NEX Trading"					=> [ "NEX" , "NEX_ODD" , "NEX_VOD" ] ,
	"TSX High Dark"					=> [ "T_HI_DARK_DARK" , "T_HI_LIT_DARK" ,
										"T_HI_DARK_LIT" , "T_HI_DARK_LIT_INTL" , "T_HI_DARK_LIT_ETF" ] ,
	"TSXV High Dark"				=> [ "V_HI_DARK_DARK" , "V_HI_DARK_LIT" , "V_HI_LIT_DARK" ] ,
	"TSX Low Dark"					=> [ "T_LO_DARK_DARK_T1" , "T_LO_DARK_DARK_T2" , 
										"T_LO_DARK_LIT_T1" , "T_LO_DARK_LIT_T2" , 
										"T_LO_LIT_DARK_T1" , "T_LO_LIT_DARK_T2" ] ,
	"TSXV Low Dark"					=> [ "V_LO_DARK_DARK_T1" , "V_LO_DARK_DARK_T2" , 
										"V_LO_DARK_LIT_T1" , "V_LO_DARK_LIT_T2" , 
										"V_LO_LIT_DARK_T1" , "V_LO_LIT_DARK_T2" ]
);

my %clobProdMap = ( 
	"TSX High CLOB"					=> [ "T_HI_CLOB" , "T_HI_CLOB_ICE" , "T_HI_CLOB_JIT" , 
										"T_HI_CLOB_INTL" , "T_HI_CLOB_ICE_INTL" , "T_HI_CLOB_JIT_INTL" ,
										"T_HI_CLOB_ETF" , "T_HI_CLOB_ETF_ICE" , "T_HI_CLOB_ETF_JIT" , 
										"T_HI_CLOB_CORR" ] , 
	"TSX Venture High CLOB"			=> [ "V_HI_CLOB" , "V_HI_CLOB_ICE" , "V_HI_CLOB_JIT" ,
										"V_HI_DEBT" , "V_HI_DEBT_ICE" , "V_HI_DEBT_JIT" ,
										"V_HI_CLOB_CORR" ] ,
	"TSX Low CLOB"					=> [ "T_LO_CLOB_T1_REG" , "T_LO_CLOB_ICE_T1" , "T_LO_CLOB_JITNEY_T1" ,
										"T_LO_CLOB_T2_REG" , "T_LO_CLOB_ICE_T2" , "T_LO_CLOB_JITNEY_T2" ,
										"T_LO_CLOB_CORR" ] ,
	"TSX Venture Low CLOB"			=> [ "V_LO_CLOB_T1_REG" , "V_LO_CLOB_JIT_T1" , "V_LO_CLOB_ICE_T1" ,
										"V_LO_CLOB_T2_REG" , "V_LO_CLOB_ICE_T2" , "V_LO_CLOB_JIT_T2" ,
										"V_LO_CLOB_CORR" ]
);

my %rtProdMap = (
	"TSX ETF RT"					=> [ "T_HI_ETF_RT" , "T_LO_ETF_RT" ,
										"T_HI_ETF_RT_OL" , "T_LO_ETF_RT_OL" ,
										"T_HI_ETF_MOC_RT" , "T_LO_ETF_MOC_RT" ] ,
	"TSX RT"						=> [ "T_HI_RT" , "T_HI_RT_INTL" , "T_LO_RT" , 
										"T_HI_RT_OL" , "T_LO_RT_OL" ,
										"T_HI_MOC_RT" , "T_LO_MOC_RT" ]
);

my %vodProdMap = (
	"TSXV VOD"						=> [ "V_HI_VOD" , "V_LO_VOD" , 
										"V_HI_VOD_OL_AUTOFILL" , "V_LO_VOD_OL_AUTOFILL" ,
										"V_HI_MOC_VOD" , "V_LO_MOC_VOD" ]										
);

sub calcRTFees {
	my ( $rtFeeMap , $rtSymCredit , $nonRTTrdFee ) = @_;
	
	my $totRTTrdFee = 0;
	foreach my $rtProd ( keys %$rtFeeMap ) {
		$totRTTrdFee += $$rtFeeMap{ $rtProd };
	}
	
	if ( $totRTTrdFee + $nonRTTrdFee + $rtSymCredit < 0 ) {
		$$rtFeeMap{ "RT Sub-Total" } = $nonRTTrdFee + $rtSymCredit;
		if ( $$rtFeeMap{ "RT Sub-Total" } > 0 ) {
			$$rtFeeMap{ "RT Sub-Total" } *= -1;
			$$rtFeeMap{ "RT Rebate" } = $totRTTrdFee + $nonRTTrdFee + $rtSymCredit;
		}
		else {
			$$rtFeeMap{ "RT Sub-Total" } = 0;
			$$rtFeeMap{ "RT Rebate" } = $totRTTrdFee;
		}
	}
	else {
		$$rtFeeMap{ "RT Sub-Total" } = $totRTTrdFee;
		$$rtFeeMap{ "RT Rebate" } = 0;
	}
}
		
sub mkFeeSumm {
	my ( $feeMap , $volMap , $rtFile , $isELP ) = @_;
	
	print "Non CLOB Fees\n";
	my $nonClobTotalFee = 0;
	my $tsxNonRTFee = 0;
	foreach my $prod ( keys %nonClobProdMap ) {
		my $prodFee = 0;
		foreach my $subProd ( @{ $nonClobProdMap{ $prod } } ) {
			my $subProdFee = $$feeMap{ $subProd }{ "ACTIVE" } + $$feeMap{ $subProd }{ "PASSIVE" };
			$prodFee += $subProdFee;
			if ( $subProd =~ /^T_/ ) {
				$tsxNonRTFee += $subProdFee;
			}
		}
		$nonClobTotalFee += $prodFee;
		
		if ( $prodFee ) {
			printf "$prod,%.2f\n" , $prodFee;
		}
	}
	printf "Non-CLOB Subtotal,%.2f\n" , $nonClobTotalFee;
	
	print "\n";
	print "CLOB Fees\n";
	my $clobTotalFee = 0;
	foreach my $prod ( keys %clobProdMap ) {
		my %prodFeeMap = ();
		my $prodActFee = 0;
		my $prodPsvCrd = 0;
		foreach my $subProd ( @{ $clobProdMap{ $prod } } ) {
			foreach my $actPsv ( qw ( ACTIVE PASSIVE ) ) {
				my $subProdFee = $$feeMap{ $subProd }{ $actPsv };
				$prodFeeMap{ $actPsv } += $subProdFee;
#				print "...[$prod] [$subProd] [$actPsv] [$$volMap{ $subProd }{ $actPsv }] [$$feeMap{ $subProd }{ $actPsv }]\n";
				if ( $subProd =~ /^T_/ ) {
					$tsxNonRTFee += $subProdFee;
				}
			}
		}
		$clobTotalFee += $prodFeeMap{ "ACTIVE" } + $prodFeeMap{ "PASSIVE" };
		printf "$prod Active,%.2f\n" , $prodFeeMap{ "ACTIVE" };
		printf "$prod Passive,%.2f\n" , $prodFeeMap{ "PASSIVE" };
	}
	printf "CLOB Subtotal,%.2f\n" , $clobTotalFee;
	
	my $rtSymCredit = $rtFile->val ( {} , "Total Symbol credit" );

	my %rtFeeMap = ();
	my $totRTFee = 0;
	foreach my $prod ( keys %rtProdMap ) {
		foreach my $subProd ( @{ $rtProdMap{ $prod } } ) {
			$rtFeeMap{ $prod } += $$feeMap{ $subProd }{ "ACTIVE" } + $$feeMap{ $subProd }{ "PASSIVE" };
			$totRTFee += $rtFeeMap{ $prod };
		}
	}

	if ( $totRTFee ) {
		calcRTFees ( \%rtFeeMap , $rtSymCredit , $tsxNonRTFee ); 

		print "\n";
		print "RT Fees\n";
		foreach my $rtProd ( "TSX ETF RT" , "TSX RT" ) {
			if ( $rtFeeMap{ $rtProd } ) {
				printf "$rtProd,%.2f\n" , $rtFeeMap{ $rtProd };
			}
		}
		printf "RT Sub-Total,%.2f\n" , $rtFeeMap{ "RT Sub-Total" };
		print "\n";

		printf "RT Symbol Credit Sub-Total,%.2f\n" , $rtSymCredit;
		print "\n";
	}
	
	my %vodFeeMap = ();
	my $totVODFee = 0;
	foreach my $prod ( keys %vodProdMap ) {
		foreach my $subProd ( @{ $vodProdMap{ $prod } } ) {
			$vodFeeMap{ $prod } += $$feeMap{ $subProd }{ "ACTIVE" } + $$feeMap{ $subProd }{ "PASSIVE" };
		}
		$totVODFee += $vodFeeMap{ $prod };
	}
	
	if ( $totVODFee ) {
		print "Venture Oddlot Dealer Fees\n";
		printf "TSXV VOD,%.2f\n" , $vodFeeMap{ "TSXV VOD" };
		printf "VOD Sub-Total,%.2f\n" , $totVODFee;
		print "\n";
	}

	printf "Total,%.2f\n" , $nonClobTotalFee + $clobTotalFee 
							+ $rtFeeMap{ "RT Sub-Total" } + $rtSymCredit 
							+ $totVODFee;
	print "\n";
	
	if ( $rtFeeMap{ "RT Rebate" } ) {
		printf "RT Rebate,%.2f\n" , $rtFeeMap{ "RT Rebate" };
		print "\n";
	}
	
	if ( $isELP ) {
		printf "ELP Rebate,%.2f\n" ,
						$$feeMap{ "T_HI_ELP" }{ "ACTIVE" } + $$feeMap{ "T_HI_ELP" }{ "PASSIVE" }
						+ $$feeMap{ "T_HI_ELP_ETF" }{ "ACTIVE" } + $$feeMap{ "T_HI_ELP_ETF" }{ "PASSIVE" };
	}
}

sub applyFirmFeeLimits {
	my ( $feeMap ) = @_;
	
	my %limitBySubProd = (
		T_MOO	=> 100000 ,
		V_MOO	=> 55000
	);
	
	foreach my $subProd ( keys %limitBySubProd ) {
		my $limit = $limitBySubProd{ $subProd };
		if ( $$feeMap{ $subProd }{ "ACTIVE" } + $$feeMap{ $subProd }{ "PASSIVE" } > $limit ) {
			$$feeMap{ $subProd }{ "ACTIVE" } = $limit;
			$$feeMap{ $subProd }{ "PASSIVE" } = 0;
		}
	}
}

sub applyActiveCLOBDiscount {
	my ( $feeMap , $volMap ) = @_;
	
	my $volThresh = 250000000;
	
	my $totActVol;
	my %actVolBySubProd = ();
	
	foreach my $subProd ( qw ( T_HI_CLOB T_HI_CLOB_ETF V_HI_CLOB V_HI_DEBT ) ) {
		next if !exists $$feeMap{ $subProd };
	
		my $actVol = $$volMap{ $subProd }{ "ACTIVE" };
		my $psvVol = $$volMap{ $subProd }{ "PASSIVE" };
		$actVol /= 100 if $subProd =~ /_DEBT/;
		$actVolBySubProd{ $subProd } = $actVol;
		$totActVol += $actVol;
	}
	
	my $excessVol = $totActVol - $volThresh;
	return if $excessVol <= 0;
	
	foreach my $subProd ( qw ( T_HI_CLOB T_HI_CLOB_ETF V_HI_CLOB V_HI_DEBT ) ) {
		my $subProdExcess = $excessVol * $actVolBySubProd{ $subProd } / $totActVol;
		$$feeMap{ $subProd }{ "ACTIVE" } -= $subProdExcess * 0.0001
	}
}

sub applyRTDiscount {
	my ( $feeMap , $symFile ) = @_;
	my $fees = $FeeConv::feeMap{ 'OLD' }{ 'T_HI_RT' };
	
	print STDERR "Applying RT Discount...\n";
	foreach my $sym ( @{ $symFile->keys ( "SYMBOL" ) } ) {
		my ( $symPsvVol , $symActVol );
		foreach my $subProd ( qw ( T_HI_RT T_HI_RT_INTL T_HI_RT_OL ) ) {
			my $vol = $symFile->val ( { SYMBOL => $sym , PRODUCT => $subProd } , "TOTAL_VOLUME" );
			my $psvVol = $symFile->val ( { SYMBOL => $sym , PRODUCT => $subProd } , "PASSIVE_VOLUME" );
			my $actVol = $vol - $psvVol;
			$symPsvVol += $psvVol;
			$symActVol += $actVol;
		}
		my $totFee = ( $symPsvVol * $$fees{ 'PSV' } ) + ( $symActVol * $$fees{ 'ACT' } );
		if ( $totFee > 0 ) {
		
#			Knock the fee off the Active side (arbitrarily)..
#			-------------------------------------------------
			print STDERR "Discounting [$totFee] for sym [$sym]\n";
			$$feeMap{ 'T_HI_RT' }{ "ACTIVE" } -= $totFee;
		}
	}
}
		
sub transformNewToOld {
	my ( $feeMap , $volMap ) = @_;
	foreach my $subProd ( sort keys %$feeMap ) {
		next if ( !exists $FeeConv::feeMap{ 'NEW' }{ $subProd } || $subProd =~ /_ELP/ );

		my $newFees = $FeeConv::feeMap{ 'NEW' }{ $subProd };
		my $oldFees = $FeeConv::feeMap{ 'OLD' }{ $subProd };
		
		if ( $$newFees{ 'ACT' } == $$oldFees{ 'ACT' } && $$newFees{ 'PSV' } == $$oldFees{ 'PSV' } ) {
			next;
		}
		
		my $actVol = $$volMap{ $subProd }{ "ACTIVE" }; 
		my $psvVol = $$volMap{ $subProd }{ "PASSIVE" }; 

		print STDERR "Transforming [$subProd] [$actVol] [$psvVol] [$$feeMap{ $subProd }{ 'ACTIVE' }] [$$feeMap{ $subProd }{ 'PASSIVE' }]...\n";
		
		if ( $subProd =~ /_DEBT/ ) {
			$actVol /= 100 ; $psvVol /= 100;
		}
	
		my ( $actFee , $psvCrd );

		if ( ( $actVol && !exists $$oldFees{ 'ACT' } ) || ( $psvVol && !exists $$oldFees{ 'PSV' } ) ) {
			print STDERR "SUBPROD [$subProd] ACT [$actVol] PSV [$psvVol] NOT REPRESENTED IN FEE CONV MAP...\n";
		}
		
		if ( exists $$oldFees{ 'ACT' } ) {
			$$feeMap{ $subProd }{ "ACTIVE" } = $actVol * $$oldFees{ 'ACT' };
			print STDERR "[$subProd] ACT [$actVol] [$$newFees{ 'ACT' }] -> [$$oldFees{ 'ACT' }]\n";
		}
		if ( exists $$oldFees{ 'PSV' } ) {
			$$feeMap{ $subProd }{ "PASSIVE" } = $psvVol * $$oldFees{ 'PSV' };
			print STDERR "[$subProd] PSV [$psvVol] [$$newFees{ 'PSV' } -> [$$oldFees{ 'PSV' }]\n";
		}
		
		print STDERR "...to [$$feeMap{ $subProd }{ 'ACTIVE' }] [$$feeMap{ $subProd }{ 'PASSIVE' }]\n";
	}
}

sub readRefELP {
	my ( $refELPFile ) = @_;
	
	my %elpSymMap = ();
	open ( FILE , $refELPFile ) or die "Cannot open reference ELP File : $!";
	while ( <FILE> ) {
		chomp;
		my ( $sym , $subProd ) = split /,/;
		$elpSymMap{ $sym } = $subProd;
	}
	close FILE;
	
	return \%elpSymMap;
}
	
sub parseELP {
	my ( $feeMap ,  $volMap , $tdFile , $elpSymMap , $po , $numDays ) = @_;
	
	my %grpByTrdrID = ();

#	Grab the ELP TraderIDs and the groups they belong to.
#	-----------------------------------------------------
	foreach my $grpID ( keys %{ $FeeConv::elpGrpMap{ $po } } ) {
		foreach my $trdrID ( @{ $FeeConv::elpGrpMap{ $po }{ $grpID } } ) {
			$grpByTrdrID{ $trdrID } = $grpID;
		}
	}
	
	my %volMapByGrpID = ();
	my %subProdBySym = ();

# 	Get overall volumes in ELP eligible symbols by these TraderIDs.
#	---------------------------------------------------------------	
	foreach my $trdrID ( keys %grpByTrdrID ) {
		my $grpID = $grpByTrdrID{ $trdrID };
		foreach my $sym ( keys %$elpSymMap ) {	
			my $elpSubProd = $$elpSymMap{ $sym };
			( my $clobSubProd = $elpSubProd ) =~ s/_ELP/_CLOB/;
			my ( $grpTotVol , $grpPsvVol );
			foreach ( $clobSubProd , "${clobSubProd}_INTL" ) {
				my $totVol = $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $_ } , "TOTAL_VOLUME" );
				my $psvVol = $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $_ } , "PASSIVE_VOLUME" );
				
				if ( $totVol > 0 ) {
					$subProdBySym{ $sym } = $_;
					$volMapByGrpID{ $grpID }{ $sym }{ "TOTAL" } += $totVol;
					$volMapByGrpID{ $grpID }{ $sym }{ "PASSIVE" } += $psvVol;
				}
			}
		}
	}
	
#	Use the overall volumes to determine ELP eligibilty by group.
#	-------------------------------------------------------------
	my %eligByGrpID = ();
	foreach my $grpID ( keys %volMapByGrpID ) {
		my ( $totVol , $totPsvVol , $numSyms );
		foreach my $sym ( keys %{ $volMapByGrpID{ $grpID } } ) {
			my $vol = $volMapByGrpID{ $grpID }{ $sym }{ "TOTAL" };
			if ( $vol > 0 ) {
				$totVol += $vol;
				$totPsvVol += $volMapByGrpID{ $grpID }{ $sym }{ "PASSIVE" };
				$numSyms++;
			}
		}
		my $psvFrac = ( $totVol == 0 ? 0 : $totPsvVol / $totVol );
		my $avgPsvVol = $totPsvVol / $numDays;
		my $eligible = ( $numSyms >= 25 && $avgPsvVol >= 500000 && $psvFrac >= 0.65 );
		$eligByGrpID{ $grpID } = $eligible;
		print "PO [$po] GRP [$grpID] : NUM [$numSyms] TOT [$totVol] PSV [$totPsvVol] FRAC [$psvFrac] AVG PSV [$avgPsvVol] ELIG [$eligible]\n";
	}
	
#	For each ELP-eligible group, transfer ELP eligible fees to ELP subproducts.
#	Note - converting to "OLD" ELP fees at the same time.
#	---------------------------------------------------------------------------
	foreach my $grpID ( keys %volMapByGrpID ) {
		if ( !$eligByGrpID{ $grpID } ) {
			next;
		}
		foreach my $sym ( keys %{ $volMapByGrpID{ $grpID } } ) {
			my $elpSubProd = $$elpSymMap{ $sym };
			my $clobSubProd = $subProdBySym{ $sym };
			
			my $elpSubProdFees = $FeeConv::feeMap{ OLD }{ $elpSubProd };	# --- OLD ELP fees, not NEW ---
			my $clobSubProdFees = $FeeConv::feeMap{ NEW }{ $clobSubProd };
			
			my $vol = $volMapByGrpID{ $grpID }{ $sym }{ "TOTAL" };
			my $psvVol = $volMapByGrpID{ $grpID }{ $sym }{ "PASSIVE" };
			my $elpPsvFee = $psvVol * $$elpSubProdFees{ PSV };
			my $elpActFee = ( $vol - $psvVol ) * $$elpSubProdFees{ ACT };
			my $clobPsvFee = $psvVol * $$clobSubProdFees{ PSV };
			my $clobActFee = ( $vol - $psvVol ) * $$clobSubProdFees{ ACT };

#			printf "$sym,$vol,$psvVol,$elpSubProd,%.2f,$clobSubProd,%.2f\n" , $elpFee , $clobFee;

			$$feeMap{ $elpSubProd }{ "ACTIVE" } += $elpActFee;
			$$feeMap{ $elpSubProd }{ "PASSIVE" } += $elpPsvFee;
			$$volMap{ $elpSubProd }{ "ACTIVE" } += $vol - $psvVol;
			$$volMap{ $elpSubProd }{ "PASSIVE" } += $psvVol;
			
			$$feeMap{ $clobSubProd }{ "ACTIVE" } -= $clobActFee;
			$$feeMap{ $clobSubProd }{ "PASSIVE" } -= $clobPsvFee;
			$$volMap{ $clobSubProd }{ "ACTIVE" } -= $vol - $psvVol;
			$$volMap{ $clobSubProd }{ "PASSIVE" } -= $psvVol;
		}
	}	
}

sub collapse {
	my ( $feeMap , $volMap ) = @_;
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %{ $FeeConv::collapseMap{ "NEW" } } ) {
		foreach my $subProd ( @{ $FeeConv::collapseMap{ "NEW" }{ $baseSubProd } } ) {
			$revCollapseMap{ $subProd } = $baseSubProd;
		}
	}

	foreach my $subProd ( keys %revCollapseMap ) {

		next if !exists $$feeMap{ $subProd };
		
		my $baseSubProd = $revCollapseMap{ $subProd };
		my $baseFees = $FeeConv::feeMap{ 'NEW' }{ $baseSubProd };
		
		print STDERR "Collapsing [$subProd] into [$baseSubProd]...\n";
	
		my $actVol = $$volMap{ $subProd }{ "ACTIVE" }; 
		my $psvVol = $$volMap{ $subProd }{ "PASSIVE" }; 
		
		if ( exists $$baseFees{ 'ACT' } ) {
			$$feeMap{ $baseSubProd }{ "ACTIVE" } += $actVol * $$baseFees{ 'ACT' };
			print STDERR "[$subProd] ACT [$actVol] -> [$$baseFees{ 'ACT' }]\n";
		}
		if ( exists $$baseFees{ 'PSV' } ) {
			$$feeMap{ $baseSubProd }{ "PASSIVE" } += $psvVol * $$baseFees{ 'PSV' };
			print STDERR "[$subProd] PSV [$psvVol] -> [$$baseFees{ 'PSV' }]\n";
		}
		
		$$volMap{ $baseSubProd }{ "ACTIVE" } += $actVol;
		$$volMap{ $baseSubProd }{ "PASSIVE" } += $psvVol;
		
		delete $$feeMap{ $subProd };
		delete $$volMap{ $subProd };
	}
}		

# Usage : revertFeeChg.pl poNum acctSummFile trdrDetailCLOBFile trdrDetailNonCLOBFile elpRefFile daysInMonth
my $po = $ARGV[ 0 ];
my $isELP = 1;
if ( !exists $FeeConv::elpGrpMap{ $po } ) {
	print STDERR "$po : Not an ELP PO\n";
	$isELP = 0;
}

my $asFile = new AccountSumm (
					file	=> $ARGV[ 1 ]
				);
		

my $tdFile = new TraderDetail (
					file	=> $ARGV[ 2 ]
				);

my $symFile = new SymbolSumm (
					file	=> $ARGV[ 3 ]
				);
				
my $rtFile = new RTSymCredit (
					file	=> $ARGV[ 4 ]
				);
				
my $elpSymMap = readRefELP ( $ARGV[ 5 ] );

my $numDaysInMonth = $ARGV[ 6 ];

my %feeBySubProd = ();
my %volBySubProd = ();

foreach my $subProd ( @{ $asFile->keys ( 'PRODUCT' ) } ) {

	my $totVol = $asFile->val ( { PRODUCT => $subProd } , "TOTAL_VOLUME" );
	my $psvVol = $asFile->val ( { PRODUCT => $subProd } , "PASSIVE_VOLUME" );
	$volBySubProd{ $subProd }{ "PASSIVE" } = $psvVol;
	$volBySubProd{ $subProd }{ "ACTIVE" } = $totVol - $psvVol;
												
	if ( exists $FeeConv::noActPsvFeeProds{ $subProd } ) {
		$feeBySubProd{ $subProd }{ "ACTIVE" } = $asFile->val ( { PRODUCT => $subProd } , "BASIC_FEE" );
		$feeBySubProd{ $subProd }{ "PASSIVE" } = 0;
	}
	else {
		$feeBySubProd{ $subProd }{ "PASSIVE" } = $asFile->val ( { PRODUCT => $subProd } , "PASSIVE_CREDIT" );
		$feeBySubProd{ $subProd }{ "ACTIVE" } = $asFile->val ( { PRODUCT => $subProd } , "ACTIVE_FEE" );
	}
}

print STDERR "\n";
foreach my $subProd ( sort keys %volBySubProd ) {
		printf STDERR "$subProd,%d,%d,%.2f,%.2f\n" , $volBySubProd{ $subProd }{ "ACTIVE" } , 
												$volBySubProd{ $subProd }{ "PASSIVE" } ,
												$feeBySubProd{ $subProd }{ "ACTIVE" } ,
												$feeBySubProd{ $subProd }{ "PASSIVE" };
}

print STDERR "\n";	
	
if ( $isELP ) {
	parseELP ( \%feeBySubProd , \%volBySubProd , $tdFile , $elpSymMap , $po , $numDaysInMonth );
}

foreach my $subProd ( sort keys %volBySubProd ) {
		printf STDERR "$subProd,%d,%d,%.2f,%.2f\n" , $volBySubProd{ $subProd }{ "ACTIVE" } , 
												$volBySubProd{ $subProd }{ "PASSIVE" } ,
												$feeBySubProd{ $subProd }{ "ACTIVE" } ,
												$feeBySubProd{ $subProd }{ "PASSIVE" };
}

print STDERR "\n";	
	
collapse ( \%feeBySubProd , \%volBySubProd );

foreach my $subProd ( sort keys %volBySubProd ) {
		printf STDERR "$subProd,%d,%d,%.2f,%.2f\n" , $volBySubProd{ $subProd }{ "ACTIVE" } , 
												$volBySubProd{ $subProd }{ "PASSIVE" } ,
												$feeBySubProd{ $subProd }{ "ACTIVE" } ,
												$feeBySubProd{ $subProd }{ "PASSIVE" };
}

print "\n";

transformNewToOld ( \%feeBySubProd , \%volBySubProd );

foreach my $subProd ( sort keys %volBySubProd ) {
		printf STDERR "$subProd,%d,%d,%.2f,%.2f\n" , $volBySubProd{ $subProd }{ "ACTIVE" } , 
												$volBySubProd{ $subProd }{ "PASSIVE" } ,
												$feeBySubProd{ $subProd }{ "ACTIVE" } ,
												$feeBySubProd{ $subProd }{ "PASSIVE" };
}

print STDERR "\n";

applyActiveCLOBDiscount ( \%feeBySubProd , \%volBySubProd );

applyFirmFeeLimits ( \%feeBySubProd );

applyRTDiscount ( \%feeBySubProd , $symFile );

foreach my $subProd ( sort keys %volBySubProd ) {
		printf STDERR "$subProd,%d,%d,%.2f,%.2f\n" , $volBySubProd{ $subProd }{ "ACTIVE" } , 
												$volBySubProd{ $subProd }{ "PASSIVE" } ,
												$feeBySubProd{ $subProd }{ "ACTIVE" } ,
												$feeBySubProd{ $subProd }{ "PASSIVE" };
}

print STDERR "\n";
mkFeeSumm ( \%feeBySubProd , \%volBySubProd , $rtFile , $isELP );