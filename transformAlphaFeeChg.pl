#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Data::Dumper;

use Billing::AlphaTraderDetail;
use Billing::FeeConvAlpha;

sub splitVol {
	my ( $vol , $val ) = @_;
	my $unitPrc = $val / $vol;
	my $blSize = ( $unitPrc >= 1.00 ? 100 :
					$unitPrc >= 0.50 ? 500 :
					1000 
				);
	return ( $vol - $vol % $blSize , $vol % $blSize );
}

sub transformPrice {
	my ( $tdFile , $mode ) = @_;
	
	my $otherMode = ( $mode eq 'NEW' ? 'OLD' : 'NEW' );

	
	foreach my $keys (
		grep { 
			exists $FeeConvAlpha::feeMap{ $mode }{ $$_{ "PRODUCT" } }
		} @{ $tdFile->allKeys () } 
	) {
		my $vol = $tdFile->val ( $keys , "TOTAL_VOLUME" );
		next if ( $vol == 0 );
		
		my $subProd = $$keys{ PRODUCT };
		my $theseFees = $FeeConvAlpha::feeMap{ $mode }{ $subProd };
		my $otherFees = $FeeConvAlpha::feeMap{ $otherMode }{ $subProd };
		if ( $$theseFees{ 'ACT' } == $$otherFees{ 'ACT' } && $$theseFees{ 'PSV' } == $$otherFees{ 'PSV' } ) {
			next;
		}
		
		my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
		
		if ( $subProd =~ /_DEBT/ ) {
			$vol /= 100 ; $psvVol /= 100;
		}

		my $actFee = $tdFile->val ( $keys , "ACTIVE_FEE" );
		my $psvFee = $tdFile->val ( $keys , "PASSIVE_FEE" );
		
		my $otherActFee = ( $vol - $psvVol ) * $$otherFees{ ACT };
		my $otherPsvCrd = $psvVol * $$otherFees{ PSV };

		print STDERR "Transforming [" , join ( "|" , values %$keys  ) , "] [" ,	$vol - $psvVol , "] [$psvVol] [$actFee]->[$otherActFee] [$psvFee]->[$otherPsvCrd]...\n";

		foreach my $valFld ( qw ( ACTIVE_FEE PASSIVE_FEE NET_FEE ) ) {
							
			my $val = (
				$valFld eq "ACTIVE_FEE" ? $otherActFee :
				$valFld eq "PASSIVE_FEE" ? $otherPsvCrd :
				$valFld eq "NET_FEE" ? ( $otherActFee + $otherPsvCrd ) :
				0
			);
				
			$tdFile->delete ( $keys , $valFld );
			$tdFile->add ( $keys , $valFld , $val );
		}
#		print STDERR "...[" , join ( "|" , values %$keys  ) , "] [" , $tdFile->val ( $keys , "NET_FEE" ) , "]\n";
	}
}


sub collapse {
	my ( $tdFile , $mode ) = @_;
	
	my %revCollapseMap = ();
	foreach my $baseSubProd ( keys %{ $FeeConvAlpha::collapseMap{ $mode } } ) {
		my $subProds = $FeeConvAlpha::collapseMap{ $mode }{ $baseSubProd };
		if ( ref $subProds ne 'HASH' ) {
			$subProds = { PSV => $subProds , ACT => $subProds };
		}
		
		foreach my $actPsv ( keys %$subProds ) {
			foreach my $subProd ( @{ $$subProds{ $actPsv } } ) {
				$revCollapseMap{ $subProd }{ $actPsv } = $baseSubProd;
			}
		}
	}

	foreach my $keys (
		grep { 
			exists $revCollapseMap{ $$_{ "PRODUCT" } }
		} @{ $tdFile->allKeys () }
	) {
		my $subProd = $$keys{ "PRODUCT" };
		
		foreach my $actPsv ( keys %{ $revCollapseMap{ $subProd } } ) {
			my $baseSubProd = $revCollapseMap{ $subProd }{ $actPsv };
		
			my $baseFees = $FeeConvAlpha::feeMap{ $mode }{ $baseSubProd };	

			my %baseKeys = %$keys;
			$baseKeys{ "PRODUCT" } = $baseSubProd;

			my $totVol = $tdFile->val ( $keys , "TOTAL_VOLUME" );		
			my $psvVol = $tdFile->val ( $keys , "PASSIVE_VOLUME" );
			my $vol = ( $actPsv eq 'PSV' ? $psvVol : $totVol - $psvVol );

			next if $vol == 0;

			my $fee = $vol * $$baseFees{ $actPsv };
			
			my $totTrds = $tdFile->val ( $keys , "TOTAL_TRADES" );
			my $psvTrds = $tdFile->val ( $keys , "PASSIVE_TRADES" );
			my $trds = ( $actPsv eq 'PSV' ? $psvTrds : $totTrds - $psvTrds );
			
			my $totVal = $tdFile->val ( $keys , "TOTAL_VALUE" );
			my $psvVal = $tdFile->val ( $keys , "PASSIVE_VALUE" );
			my $val = ( $actPsv eq 'PSV' ? $psvVal : $totVal - $psvVal );

#			Special handling - attempt to collapse only the odd-lot trade quantity into any Autofill buckets.
#			-------------------------------------------------------------------------------------------------
			if ( $actPsv eq 'PSV' && $baseSubProd =~ /Autofill/ ) {
				my ( $blVol , $olVol ) = splitVol ( $vol , $val );
				next if $olVol == 0;
			
				$fee *= $olVol / $vol;
				$trds = 1;	# --- no way to know this ---
				$val *= $olVol / $vol;	# --- approximation ---
				$vol = $olVol;
			}
				
			print STDERR "Collapsing [" , join ( "|" , values %$keys  ) , "] [$actPsv] trds [$trds] vol [$vol] val [$val] fee [$fee] into [" , join ( "|" , values %baseKeys ) , "]...\n";		

			foreach my $valFld ( @{ $tdFile->{valFlds} } ) {
				my $val = (
					$valFld eq "TOTAL_TRADES" ? $trds :
					$valFld eq "PASSIVE_TRADES" ? ( $actPsv eq 'PSV' ? $trds : 0 ) :
					$valFld eq "TOTAL_VOLUME" ? $vol :
					$valFld eq "PASSIVE_VOLUME" ? ( $actPsv eq 'PSV' ? $vol : 0 ) :
					$valFld eq "TOTAL_VALUE" ? $val :
					$valFld eq "PASSIVE_VALUE" ? ( $actPsv eq 'PSV' ? $val : 0 ) :
					$valFld eq "ACTIVE_FEE" ? ( $actPsv eq 'ACT' ? $fee : 0 ) :
					$valFld eq "PASSIVE_FEE" ? ( $actPsv eq 'PSV' ? $fee : 0 ) :
					$valFld eq "NET_FEE" ? $fee :
					0
				);
				
				$tdFile->add ( \%baseKeys , $valFld , $val );
				
				if ( $vol == $totVol ) {
					$tdFile->delete ( $keys , $valFld );
				}
				else {
					$tdFile->add ( $keys , $valFld , ( $val * -1 ) );
				}
			}
		}
	}
}		

# Usage : transformAlphaFeeChg.pl (-o|-n) [-p] trdrDetailCLOBFile trdrDetailNonCLOBFile

my ( $oldMode , $newMode , $transformPrice );
GetOptions ( 
	'o'	=> \$oldMode ,
	'n' => \$newMode ,
	'p' => \$transformPrice
) or die;

exit 1 if ( ( $oldMode && $newMode ) || ( !$oldMode && !$newMode ) );
my $mode = ( $oldMode ? "OLD" : "NEW" );

my $tdFile = new AlphaTraderDetail (
					file	=> [ $ARGV[ 0 ] , $ARGV[ 1 ] ]
				);
	
collapse ( $tdFile , $mode );

if ( $transformPrice ) {
	transformPrice ( $tdFile , $mode );
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

transformNewToOld ( $tdFile );

applyActiveCLOBDiscount ( $tdFile );

applyFirmFeeLimits ( $tdFile );

applyRTDiscount ( $tdFile );

print join ( "," , @{ $tdFile->{keyFlds} } ) , "," , join ( "," , @{ $tdFile->{valFlds} } ) , "\n";
foreach my $keys (
	grep { 
		$tdFile->val ( $_ , "TOTAL_VOLUME" ) > 0
	} @{ $tdFile->keys () }
) {
	print $tdFile->dumpRec ( $keys ) , "\n";
}		
exit;

print STDERR "\n";
