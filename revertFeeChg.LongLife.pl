#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Data::Dumper;

use Billing::TraderDetail;
use Billing::FeeConvLongLife;

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

sub applyRTDiscount {
	my ( $tdFile ) = @_;
	my $fees = $FeeConvLongLife::feeMap{ 'OLD' }{ 'T_HI_RT' };
	
	print STDERR "Applying RT Discount...\n";

	my %feeBySym = ();
	my %symKeyList = ();
	
	foreach my $keys (
		grep { 
			$$_{ PRODUCT } =~ /^T_HI(_MOC)?_RT(_OL)?$/
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
			exists $FeeConvLongLife::feeMap{ 'NEW' }{ $$_{ "PRODUCT" } }
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $subProd = $$keys{ PRODUCT };
		my $newFees = $FeeConvLongLife::feeMap{ 'NEW' }{ $subProd };
		my $oldFees = $FeeConvLongLife::feeMap{ 'OLD' }{ $subProd };
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


sub collapse {
	my ( $tdFile ) = @_;
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %{ $FeeConvLongLife::collapseMap{ "NEW" } } ) {
		foreach my $subProd ( @{ $FeeConvLongLife::collapseMap{ "NEW" }{ $baseSubProd } } ) {
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
		my $baseFees = $FeeConvLongLife::feeMap{ 'NEW' }{ $baseSubProd };	

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

# Usage : revertFeeChg.LongLife.pl trdrDetailCLOBFile trdrDetailNonCLOBFile

my $tdFile = new TraderDetail (
					file	=> [ $ARGV[ 0 ] , $ARGV[ 1 ] ]
				);

my %feeBySubProd = ();
my %volBySubProd = ();

# For sub-products whose Passive/Active Fee columns are not filled in, grab from Basic Fee 
# and treat (arbitrarily) as Active.
# ----------------------------------------------------------------------------------------
# my $basicFeeVals = $tdFile->{valMap}{ "BASIC_FEE" };
# my $activeFeeVals = $tdFile->{valMap}{ "ACTIVE_FEE" };

foreach my $keys (
	grep { 
		exists $FeeConvLongLife::noActPsvFeeProds{ $$_{ "PRODUCT" } }
	} @{ $tdFile->allKeys () }
) {
	$tdFile->add ( $keys , "ACTIVE_FEE" , $tdFile->val ( $keys , "BASIC_FEE" ) );
}

collapse ( $tdFile );

transformNewToOld ( $tdFile );

applyFirmFeeLimits ( $tdFile );

applyRTDiscount ( $tdFile );

# Zero back out the Active Fees set above.
# ----------------------------------------
foreach my $keys (
	grep { 
		exists $FeeConvLongLife::noActPsvFeeProds{ $$_{ "PRODUCT" } }
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
