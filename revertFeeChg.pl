#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Data::Dumper;

use Billing::TraderDetail;
use Billing::FeeConv;

sub applyFirmFeeLimits {
	my ( $tdFile ) = @_;
	
	my %limitBySubProd = (
		T_MOO	=> 100000 ,
		V_MOO	=> 55000
	);
	my %feeBySubProd = (
		T_MOO	=> $tdFile->val ( { PRODUCT => "T_MOO" } , "BASIC_FEE" ) ,
		V_MOO	=> $tdFile->val ( { PRODUCT => "V_MOO" } , "BASIC_FEE" )
	);

	foreach my $subProd ( keys %limitBySubProd ) {
		my $limit = $limitBySubProd{ $subProd };
		my $totFee = $feeBySubProd{ $subProd };
		next if $totFee <= $limit;
		
		foreach my $keys (
			grep { 
				$$_{ PRODUCT } eq $subProd
			} @{ $tdFile->allKeys () } 
		) {
			my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
			next if ( $vol == 0 );
			
			my $fee = $tdFile->val ( $keys , "BASIC_FEE" );
			my $discount = ( $totFee - $limit ) * $fee / $totFee;
		
			print STDERR "firmFeeLimits : Adjusting net fee [" , join ( "|" , values %$keys  ) , "] by [$discount]...\n";
			$tdFile->delete ( $keys , "NET_FEE" );
			$tdFile->add ( $keys , "NET_FEE" , $fee - $discount );
		}
	}
}

sub applyActiveCLOBDiscount {
	my ( $tdFile ) = @_;
	
	my $volThresh = 250000000;
	
	my $totActVol;
	my %actVolBySubProd = ();

#	Sum up the total applicable Active volume.
#	------------------------------------------
	foreach my $keys (
		grep { 
			$$_{ PRODUCT } =~ /^(T_HI_CLOB(_ETF)?|V_HI_(CLOB|DEBT))$/
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		my $subProd = $$keys{ PRODUCT };
		my $actVol = $vol - $psvVol;
		$actVol /= 100 if $subProd =~ /_DEBT/;
		
		$actVolBySubProd{ $subProd } += $actVol;
		$totActVol += $actVol;
	}

#	Check the Active volume exceeds the threshold for discount.
#	-----------------------------------------------------------	
	my $excessVol = $totActVol - $volThresh;
	return if $excessVol <= 0;
	
#	Apply the discount to the records.
#	----------------------------------
	foreach my $keys (
		grep { 
			$$_{ PRODUCT } =~ /^(T_HI_CLOB(_ETF)?|V_HI_(CLOB|DEBT))$/
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		my $subProd = $$keys{ PRODUCT };
		my $actVol = $vol - $psvVol;
		$actVol /= 100 if $subProd =~ /_DEBT/;
		
		my $discount = $excessVol * $actVol / $totActVol * -0.0001;
		
		print STDERR "activeCLOB : Adjusting net fee [" , join ( "|" , values %$keys  ) , "] by [$discount]...\n";
		$tdFile->add ( $keys , "NET_FEE" , $discount );
	}
}

sub applyRTDiscount {
	my ( $tdFile ) = @_;
	my $fees = $FeeConv::feeMap{ 'OLD' }{ 'T_HI_RT' };
	
	print STDERR "Applying RT Discount...\n";

	my %feeBySym = ();
	my %symKeyList = ();
	
	foreach my $keys (
		grep { 
			$$_{ PRODUCT } =~ /^T_HI(_MOC)?_RT$/
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $sym = $$keys{ Symbol };
		my $fee = $tdFile->val ( $keys , "BASIC_FEE" );
		$feeBySym{ $sym } += $fee;
		
		push @{ $symKeyList{ $sym } } , $keys;
	}
	
	foreach my $sym ( keys %symKeyList ) {
		my $symFee = $feeBySym{ $sym };

		foreach my $keys ( @{ $symKeyList{ $sym } } ) {
		
			my $fee = $tdFile->val ( $keys , "BASIC_FEE" );
			
			if ( $symFee <= 0 || $fee <= 0 ) {
				$tdFile->delete ( $keys , "NET_FEE" );
				$tdFile->add ( $keys , "NET_FEE" , $tdFile->val ( $keys , "BASIC_FEE" ) );
				next;
			}
			
			my $netFee = $tdFile->val ( $keys , "NET_FEE" );
			my $feeDiff = ( $fee < $symFee ? $fee : $symFee );
			print STDERR "applyRTDiscount : Adjusting net fee [" , join ( "|" , values %$keys  ) , "] from [$fee] [$netFee] down by [$feeDiff]...\n";
			$tdFile->delete ( $keys , "NET_FEE" );
			$tdFile->add ( $keys , "NET_FEE" , $fee - $feeDiff );
			
#			print STDERR "...[" , join ( "|" , values %$keys  ) , "] [" , $tdFile->val ( $keys , "BASIC_FEE" ) , "] [" , $tdFile->val ( $keys , "NET_FEE" ) , "]\n";
			$symFee -= $fee;
		}
	}
}
		
sub transformNewToOld {
	my ( $tdFile ) = @_;
	
	foreach my $keys (
		grep { 
			exists $FeeConv::feeMap{ 'NEW' }{ $$_{ "PRODUCT" } }
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $subProd = $$keys{ PRODUCT };
		my $newFees = $FeeConv::feeMap{ 'NEW' }{ $subProd };
		my $oldFees = $FeeConv::feeMap{ 'OLD' }{ $subProd };
		if ( $$newFees{ 'ACT' } == $$oldFees{ 'ACT' } && $$newFees{ 'PSV' } == $$oldFees{ 'PSV' } ) {
			next;
		}
		
		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		
		if ( $subProd =~ /_DEBT/ ) {
			$vol /= 100 ; $psvVol /= 100;
		}

		my $actFee = $tdFile->val ( $keys , "ACTIVE_FEE" );
		my $psvCrd = $tdFile->val ( $keys , "PASSIVE_CREDIT" );
		
		my $newActFee = ( $vol - $psvVol ) * $$oldFees{ ACT };
		my $newPsvCrd = $psvVol * $$oldFees{ PSV };

		print STDERR "Transforming [" , join ( "|" , values %$keys  ) , "] [" ,	$vol - $psvVol , "] [$psvVol] [$actFee]->[$newActFee] [$psvCrd]->[$newPsvCrd]...\n";

		foreach my $valFld ( qw ( ACTIVE_FEE PASSIVE_CREDIT BASIC_FEE NET_FEE ) ) {
							
			my $val = (
				$valFld eq "ACTIVE_FEE" ? $newActFee - $actFee :
				$valFld eq "PASSIVE_CREDIT" ? $newPsvCrd - $psvCrd :
				$valFld eq "BASIC_FEE" ? ( $newActFee + $newPsvCrd ) - ( $actFee + $psvCrd ) :
				$valFld eq "NET_FEE" ? ( $newActFee + $newPsvCrd ) - ( $actFee + $psvCrd ) :
				0
			);
				
			$tdFile->add ( $keys , $valFld , $val );
		}
#		print STDERR "...[" , join ( "|" , values %$keys  ) , "] [" , $tdFile->val ( $keys , "BASIC_FEE" ) , "] [" , $tdFile->val ( $keys , "NET_FEE" ) , "]\n";
	}
}

sub readRefELP {
	my ( $refELPFile ) = @_;
	
	my %elpSymMap = ();
	open ( FILE , $refELPFile ) or die "Cannot open reference ELP File [$refELPFile] : $!";
	while ( <FILE> ) {
		chomp;
		my ( $sym , $subProd ) = split /,/;
		$elpSymMap{ $sym } = $subProd;
	}
	close FILE;
	
	return \%elpSymMap;
}
	
sub parseELP {
	my ( $tdFile , $elpSymMap , $po , $numDays ) = @_;
	
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

#	Associate the ELP subproducts with all the CLOB subproducts that contribute to them.
#	Note that Iceberg orders do not count.  But note also that some CLOB volume is actually
#	displayed Iceberg volume, but we can't tell them apart so we pull it all in, with the
#	effect that we convert slightly too much CLOB volume over to ELP.
#	---------------------------------------------------------------------------------------
	my %elpSubProdMap = map { $_ => 1 } values %$elpSymMap;
	
	foreach my $elpSubProd ( keys %elpSubProdMap ) {
		( my $clobSubProd = $elpSubProd ) =~ s/_ELP/_CLOB/;
		$elpSubProdMap{ $elpSubProd } = [ $clobSubProd , "${clobSubProd}_JIT" ];
		
		if ( $clobSubProd !~ /_ETF/ ) {
			my @subProds = @{ $elpSubProdMap{ $elpSubProd } };
			foreach ( @subProds ) {
				push @{ $elpSubProdMap{ $elpSubProd } } , $_ . "_INTL";
			}
		}
	}
	
	my %masterClobSubProdMap = ();
	foreach my $clobSubProds ( values %elpSubProdMap ) {
		foreach ( @$clobSubProds ) {
			$masterClobSubProdMap{ $_ } = 1;
		}
	}		
	
# 	Get overall volumes in ELP eligible symbols by these TraderIDs.
#	---------------------------------------------------------------	
	foreach my $trdrID ( keys %grpByTrdrID ) {
		my $grpID = $grpByTrdrID{ $trdrID };
		foreach my $sym ( keys %$elpSymMap ) {	
			my $elpSubProd = $$elpSymMap{ $sym };
			( my $clobSubProd = $elpSubProd ) =~ s/_ELP/_CLOB/;
			my ( $grpTotVol , $grpPsvVol );
			foreach ( @{ $elpSubProdMap{ $elpSubProd } } ) {
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
	
#	Use the overall volumes to determine ELP eligibility by group.
#	--------------------------------------------------------------
	my %eligTrdrIDMap = ();
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
		if ( $eligible ) {
			foreach my $trdrID ( @{ $FeeConv::elpGrpMap{ $po }{ $grpID } } ) {
				$eligTrdrIDMap{ $trdrID } = 1;
			}
		}
		
#		print "PO [$po] GRP [$grpID] : NUM [$numSyms] TOT [$totVol] PSV [$totPsvVol] FRAC [$psvFrac] AVG PSV [$avgPsvVol] ELIG [$eligible]\n";
	}
	
#	For each ELP-eligible traderID, transfer ELP eligible fees to ELP subproducts.
#	Note - converting to "OLD" ELP fees at the same time.
#	------------------------------------------------------------------------------
	foreach my $keys (
		grep { 
			exists $eligTrdrIDMap{ $$_{ TRADER_ID } } &&
			exists $$elpSymMap{ $$_{ Symbol } } &&
			exists $masterClobSubProdMap{ $$_{ PRODUCT } }
		} @{ $tdFile->allKeys () }
	) {
		
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if $vol == 0;
		
		my $clobSubProd = $$keys{ PRODUCT };
		my $sym = $$keys{ Symbol };
		my $elpSubProd = $$elpSymMap{ $sym };
		
		my $elpSubProdFees = $FeeConv::feeMap{ OLD }{ $elpSubProd };	# --- OLD ELP fees, not NEW ---
					
		my %newKeys = %$keys;
		$newKeys{ PRODUCT } = $elpSubProd;

		print STDERR "Transferring [" , join ( "," , values %$keys ) , "] to [$elpSubProd]...\n";
		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		my $psvCrd = $psvVol * $$elpSubProdFees{ PSV };
		my $actFee = ( $vol - $psvVol ) * $$elpSubProdFees{ ACT };
							
		foreach my $valFld ( @{ $tdFile->{valFlds} } ) {
							
			my $val = (
				$valFld eq 'TOTAL_VOLUME' ? $vol :
				$valFld eq 'PASSIVE_VOLUME' ? $psvVol :
				$valFld eq "ACTIVE_FEE" ? $actFee :
				$valFld eq "PASSIVE_CREDIT" ? $psvCrd :
				$valFld eq "BASIC_FEE" ? $actFee + $psvCrd :
				$valFld eq "NET_FEE" ? $actFee + $psvCrd :
				$tdFile->val ( $keys , $valFld )
			);
				
			$tdFile->delete ( $keys , $valFld );
			$tdFile->add ( \%newKeys , $valFld , $val );
#			print STDERR "...[$valFld] [$val] [" , $tdFile->val ( \%newKeys , $valFld ) , "]...\n";
		}
	}

	foreach my $grpID ( sort keys %volMapByGrpID ) {		
		if ( !$eligByGrpID{ $grpID } ) {
			next;
		}
		foreach my $trdrID ( sort @{ $FeeConv::elpGrpMap{ $po }{ $grpID } } ) { 
			foreach my $sym ( sort keys %{ $volMapByGrpID{ $grpID } } ) {
				my $elpSubProd = $$elpSymMap{ $sym };
				my ( $trds , $val , $vol , $psvVol , $netFee );
				foreach my $clobSubProd ( ( $elpSubProd ) ) {
					$trds += $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $clobSubProd } , "TOTAL_TRADES" ); 
					$val += $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $clobSubProd } , "TOTAL_VALUE" );
					$vol += $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $clobSubProd } , "TOTAL_VOLUME" );
					$psvVol += $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $clobSubProd } , "PASSIVE_VOLUME" );
					$netFee += $tdFile->val ( { TRADER_ID => $trdrID , Symbol => $sym , PRODUCT => $clobSubProd } , "NET_FEE" );
				}
				next if !$trds;
				printf STDERR "$grpID,$trdrID,$sym,%d,%.2f,%d,%d,%.2f\n" , $trds , $val , $vol - $psvVol , $psvVol , $netFee;
			}
		}
	}
}


sub collapse {
	my ( $tdFile ) = @_;
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %{ $FeeConv::collapseMap{ "NEW" } } ) {
		foreach my $subProd ( @{ $FeeConv::collapseMap{ "NEW" }{ $baseSubProd } } ) {
			$revCollapseMap{ $subProd } = $baseSubProd;
		}
	}

	foreach my $keys (
		grep { 
			exists $revCollapseMap{ $$_{ "PRODUCT" } }
		} @{ $tdFile->allKeys () }
	) {
		my $subProd = $$keys{ "PRODUCT" };
		my $baseSubProd = $revCollapseMap{ $subProd };
		my $baseFees = $FeeConv::feeMap{ 'NEW' }{ $baseSubProd };	

		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my %baseKeys = %$keys;
		$baseKeys{ "PRODUCT" } = $baseSubProd;

		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		my $psvCrd = $psvVol * $$baseFees{ PSV };
		my $actFee = ( $vol - $psvVol ) * $$baseFees{ ACT };

		print STDERR "Collapsing [" , join ( "|" , values %$keys  ) , "] [" , $vol - $psvVol , "] [$psvVol] [$actFee] [$psvCrd] into [" , join ( "|" , values %baseKeys ) , "]...\n";
#		print STDERR "...[" , join ( "|" , values %$keys  ) , "] [" , $tdFile->val ( $keys , "BASIC_FEE" ) , "] [" , $tdFile->val ( $keys , "NET_FEE" ) , "]\n";
#		print STDERR "...[" , join ( "|" , values %baseKeys  ) , "] [" , $tdFile->val ( \%baseKeys , "BASIC_FEE" ) , "] [" , $tdFile->val ( \%baseKeys , "NET_FEE" ) , "]\n";
		
		
		my %baseKeys = %$keys;
		$baseKeys{ "PRODUCT" } = $baseSubProd;
		
		foreach my $valFld ( @{ $tdFile->{valFlds} } ) {
			my $val = (
				$valFld eq "ACTIVE_FEE" ? $actFee :
				$valFld eq "PASSIVE_CREDIT" ? $psvCrd :
				$valFld eq "BASIC_FEE" ? $actFee + $psvCrd :
				$valFld eq "NET_FEE" ? $actFee + $psvCrd :
				$tdFile->val ( $keys , $valFld )
			);

			$tdFile->delete ( $keys , $valFld );
			$tdFile->add ( \%baseKeys , $valFld , $val );
		}
#		print STDERR "...[" , join ( "|" , values %baseKeys  ) , "] [" , $tdFile->val ( \%baseKeys , "BASIC_FEE" ) , "] [" , $tdFile->val ( \%baseKeys , "NET_FEE" ) , "]\n";
	}
}		

# Usage : revertFeeChg.pl poNum trdrDetailCLOBFile trdrDetailNonCLOBFile elpRefFile daysInMonth
my $po = $ARGV[ 0 ];
my $isELP = 1;
if ( !exists $FeeConv::elpGrpMap{ $po } ) {
	print STDERR "$po : Not an ELP PO\n";
	$isELP = 0;
}

my $tdFile = new TraderDetail (
					file	=> [ $ARGV[ 1 ] , $ARGV[ 2 ] ]
				);

my $elpSymMap = readRefELP ( $ARGV[ 3 ] );

my $numDaysInMonth = $ARGV[ 4 ];

my %feeBySubProd = ();
my %volBySubProd = ();

# For sub-products whose Passive/Active Fee columns are not filled in, grab from Basic Fee 
# and treat (arbitrarily) as Active.
# ----------------------------------------------------------------------------------------
# my $basicFeeVals = $tdFile->{valMap}{ "BASIC_FEE" };
# my $activeFeeVals = $tdFile->{valMap}{ "ACTIVE_FEE" };

foreach my $keys (
	grep { 
		exists $FeeConv::noActPsvFeeProds{ $$_{ "PRODUCT" } }
	} @{ $tdFile->allKeys () }
) {
	$tdFile->add ( $keys , "ACTIVE_FEE" , $tdFile->val ( $keys , "BASIC_FEE" ) );
}

if ( $isELP ) {
	parseELP ( $tdFile , $elpSymMap , $po , $numDaysInMonth );
}
	
collapse ( $tdFile );

transformNewToOld ( $tdFile );

applyActiveCLOBDiscount ( $tdFile );

applyFirmFeeLimits ( $tdFile );

applyRTDiscount ( $tdFile );

# Zero back out the Active Fees set above.
# ----------------------------------------
foreach my $keys (
	grep { 
		exists $FeeConv::noActPsvFeeProds{ $$_{ "PRODUCT" } }
	} @{ $tdFile->allKeys () }
) {
	$tdFile->add ( $keys , "ACTIVE_FEE" , $tdFile->val ( $keys , "ACTIVE_FEE" ) * -1 );
}

print join ( "," , @{ $tdFile->{keyFlds} } ) , "," , join ( "," , @{ $tdFile->{valFlds} } ) , "\n";
foreach my $keys (
	grep { 
		$tdFile->val ( $_ , "TOTAL_VOLUME" ) > 0
	} @{ $tdFile->allKeys () }
) {
	print $tdFile->dumpRec ( $keys ) , "\n";
}		
exit;

print STDERR "\n";
