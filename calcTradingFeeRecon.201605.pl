#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use POSIX qw ( strftime );
use Time::Local;
use Data::Dumper;

use File::Basename;
my $scriptName = basename $0;

use lib dirname $0;

use TMX;
use Alpha;
use Billing::TSXProdMap;
use Billing::AlphaProdMap;

use Billing::TdrSaleSumm;
use Billing::PoFeeReconSumm;

sub usageAndExit {
	print STDERR "Usage : " , $scriptName , " -m yyyymm -r billingFileDir\n";
	exit 1;
}

sub mkPctChg {
	my ( $curr , $prev ) = @_;
	return ( $prev == 0 ? 0 : ( $curr - $prev ) / $prev );
}

sub mkDateLabel {
	my ( $yyyy , $mm ) = @_;
	my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );
	return "$mmm $yyyy";
}

sub showProducts {
	my ( $thisDispMon , $prevDispMon , $currPOSumFile , $prevPOSumFile , $currQtyMap , $prevQtyMap , $subProdMap ) = @_;

	print "MSGP PRODUCT DESCRIPTION," ,
			"TOTAL FEE CURRENT MONTH ($thisDispMon),TOTAL FEE PREVIOUS MONTH ($prevDispMon),% CHANGE,ABS CHANGE," ,
			"TOTAL VOL CURRENT MONTH ($thisDispMon),TOTAL VOL PREVIOUS MONTH ($prevDispMon),% CHANGE,ABS CHANGE\n";
	
#	Make a SubProduct => Product map.
#	---------------------------------
	my %productMap = ();
	foreach my $product ( keys %$subProdMap ) {
		foreach my $subProduct ( @{ $$subProdMap{ $product } } ) {
			$productMap{ $subProduct } = $product;
		}
	}

#	Grab fees and quantities by Product.
#	------------------------------------
	my ( %currQtyByProduct , %prevQtyByProduct );
	
#	--- current month ---
	foreach my $subProd ( keys %$currQtyMap ) {
		my $product = $productMap{ $subProd };
		if ( !$product ) {
			print STDERR "WARNING : Unknown product for subproduct [$subProd].\n";
			$product = "UNKNOWN";
		}
		foreach my $qtyType ( keys %{ $$currQtyMap{ $subProd } } ) {
			my $qty = $$currQtyMap{ $subProd }{ $qtyType };
			$currQtyByProduct{ $product }{ $qtyType } += $qty;
			if ( $qtyType eq 'VOL' ) {
#				print STDERR "$product,$subProd,$qty\n";
			}
		}
	}
	
#	--- and previous month ---
	foreach my $subProd ( keys %$prevQtyMap ) {
		my $product = $productMap{ $subProd };
		if ( !$product ) {
			print STDERR "WARNING : Unknown product for subproduct [$subProd].\n";
			$product = "UNKNOWN";
		}
		foreach my $qtyType ( keys %{ $$prevQtyMap{ $subProd } } ) {
			my $qty = $$prevQtyMap{ $subProd }{ $qtyType };
			$prevQtyByProduct{ $product }{ $qtyType } += $qty;
		}
	}		

#	Note - we use fees directly from the POFEERECONSUM file, as they're more complete
#	(they include monthly subscription fees).
#	----------------------------------------------------------------------------------
	my $currProds = $currPOSumFile->prodList ();
	my $currFeeByProd = $currPOSumFile->feeByProd ();
	my $prevProds = $prevPOSumFile->prodList ();
	my $prevFeeByProd = $prevPOSumFile->feeByProd ();
		
	my ( $currTotFee , $currTotVol , $prevTotFee , $prevTotVol );

	foreach my $product ( @$currProds ) {

		my $currFee = $$currFeeByProd{ $product };
		my $prevFee = delete $$prevFeeByProd{ $product };
		$currTotFee += $currFee;
		$prevTotFee += $prevFee;
		if ( !Util::valMatch ( $currFee , $currQtyByProduct{ $product }{ "FEE" } ) ) {
			print STDERR "Current fee mismatch: [$product] : RECON [$currFee] TDRS [$currQtyByProduct{ $product }{ 'FEE' }]\n";
		}
		if ( !Util::valMatch ( $prevFee , $prevQtyByProduct{ $product }{ "FEE" } ) ) {
			print STDERR "Previous fee mismatch: [$product] : RECON [$prevFee] TDRS [$prevQtyByProduct{ $product }{ 'FEE' }]\n";
		}
				
		my $currVol = delete $currQtyByProduct{ $product }{ "VOL" };
		my $prevVol = delete $prevQtyByProduct{ $product }{ "VOL" };
		$currTotVol += $currVol;
		$prevTotVol += $prevVol;
		
		printf "$product,%.2f,%.2f,%.3f,%.0f,%.0f,%.0f,%.3f,%.0f\n" , 
				$currFee , $prevFee , mkPctChg ( $currFee , $prevFee ) , $currFee - $prevFee ,
				$currVol , $prevVol , mkPctChg ( $currVol , $prevVol ) , $currVol - $prevVol;
	}
				
	foreach my $product ( @$prevProds ) {
		next if !exists $$prevFeeByProd{ $product };
		
		my $currFee = 0;
		my $prevFee = delete $$prevFeeByProd{ $product };
		$prevTotFee += $prevFee;
				
		my $currVol = 0;
		my $prevVol = delete $prevQtyByProduct{ $product }{ "VOL" };
		$prevTotVol += $prevVol;
		
		printf "$product,%.2f,%.2f,%.3f,%.2f,%.0f,%.0f,%.3f,%.0f\n" , 
				$currFee , $prevFee , mkPctChg ( $currFee , $prevFee ) , $currFee - $prevFee ,
				$currVol , $prevVol , mkPctChg ( $currVol , $prevVol ) , $currVol - $prevVol;
	}
		
#	Accumulate all volume without associated fees.
#	----------------------------------------------
	my ( $currExtraVol , $prevExtraVol );
	foreach my $product ( keys %currQtyByProduct ) {
		next if !exists $currQtyByProduct{ $product }{ "VOL" };
		printf STDERR "Current non-billable vol [$product]\n";
		$currExtraVol += $currQtyByProduct{ $product }{ "VOL" };
	}
	$currTotVol += $currExtraVol;
	foreach my $product ( keys %prevQtyByProduct ) {
		next if !exists $prevQtyByProduct{ $product }{ "VOL" };
		printf STDERR "Previous non-billable vol [$product]\n";
		$prevExtraVol += $prevQtyByProduct{ $product }{ "VOL" };
	}
	$prevTotVol += $prevExtraVol;

	printf "Non-billable Volume,,,,,%.0f,%.0f,%.3f,%.0f\n" ,
			$currExtraVol , $prevExtraVol , mkPctChg ( $currExtraVol , $prevExtraVol ) , $currExtraVol - $prevExtraVol;
	
	printf "Totals,%.2f,%.2f,%.3f,%.2f,%.0f,%.0f,%.3f,%.0f\n" , 
			$currTotFee , $prevTotFee , mkPctChg ( $currTotFee , $prevTotFee ) , $currTotFee - $prevTotFee ,
			$currTotVol , $prevTotVol , mkPctChg ( $currTotVol , $prevTotVol ) , $currTotVol - $prevTotVol;
}


# Parse the cmd line.
# -------------------
my $rootDir;
my $yyyymm = join ( "" , Util::prevMonth );

GetOptions ( 
	'm=s'	=> \$yyyymm ,
	"r=s"	=> \$rootDir
) or usageAndExit;

usageAndExit if ( ( !$yyyymm || $yyyymm !~ /^201\d(0[1-9]|1[012])$/ ) || !$rootDir );

my ( $yyyy , $mm ) = ( $yyyymm =~ /(....)(..)/ );
my ( $prevYYYY , $prevMM ) = Util::prevMonth ( $yyyy , $mm ); 
my $prevYYYYMM = sprintf ( "%04d%02d" , $prevYYYY , $prevMM );

# Grab the TMX files.
# -------------------
my $tmxDir = TMX::getRootDateDir ( $rootDir , $yyyymm );
if ( !$tmxDir ) {
	print STDERR "Error : could not find TMX folder matching [$yyyymm] in root [$rootDir]\n";
	exit 1;
}
my $prevTMXDir = TMX::getRootDateDir ( $rootDir , sprintf ( "%04d%02d" , ${prevYYYY} , ${prevMM} ) );

my $tmxReconFileName = ( glob ( "$tmxDir/common/pofeereconsum_$yyyy*.csv" ) )[ 0 ];
my $tmxTdrsFileName = ( glob ( "$tmxDir/common/tdrsalesum_$yyyy*.csv" ) )[ 0 ];
if ( !$tmxReconFileName || !$tmxTdrsFileName ) {
	print STDERR "ERROR : pofeereconsum and/or tdrsalesum files missing from current month folder [$tmxDir/common]\n";
	exit;
}

my $currReconFile = new PoFeeReconSumm ( file => $tmxReconFileName );
my $currQtyMap = TMX::getTdrSalesSumQtys ( $tmxTdrsFileName );

$tmxReconFileName = ( glob ( "$prevTMXDir/common/pofeereconsum_$prevYYYY*.csv" ) )[ 0 ];
$tmxTdrsFileName = ( glob ( "$prevTMXDir/common/tdrsalesum_$prevYYYY*.csv" ) )[ 0 ];
if ( !$tmxReconFileName || !$tmxTdrsFileName ) {
	print STDERR "ERROR : pofeereconsum and/or tdrsalesum files missing from previous month folder [$tmxDir/common]\n";
	exit;
}

my $prevReconFile = new PoFeeReconSumm ( file => $tmxReconFileName );
my $prevQtyMap = TMX::getTdrSalesSumQtys ( $tmxTdrsFileName );

my $thisDispMon = mkDateLabel ( $yyyy , $mm );
my $prevDispMon = mkDateLabel ( $prevYYYY , $prevMM );

print "MONTHLY TRADING FEE RECONCILIATION\n";
print "$thisDispMon vs. $prevDispMon\n\n";

print "EQUITY TRADE FEE RECONCILIATION\n\n";
showProducts ( $thisDispMon , $prevDispMon , $currReconFile , $prevReconFile , $currQtyMap , $prevQtyMap , \%TSXProdMap::subProdMap );

my $currRTRebate = $currReconFile->{poSection}->val ( {} , "BROKERS WITH RT REBATE" );
my $prevRTRebate = $prevReconFile->{poSection}->val ( {} , "BROKERS WITH RT REBATE" );
print "\n";
printf "RT Rebate,%.2f,%.2f,%.3f,%.2f\n" , $currRTRebate , $prevRTRebate , 
			mkPctChg ( $currRTRebate , $prevRTRebate ) , $currRTRebate - $prevRTRebate;

my $alphaDir = Alpha::getRootDateDir ( $rootDir , $yyyymm );
my $prevAlphaDir = Alpha::getRootDateDir ( $rootDir , $prevYYYYMM );

my $alphaReconFileName = ( glob ( "$alphaDir/common/POFEERECONSUM_$yyyy*.csv" ) )[ 0 ];
my $alphaTDRSFileName = ( glob ( "$alphaDir/common/TDRSALESUM_$yyyy*.csv" ) )[ 0 ];
my $alphaDarkTDRSFileName = ( glob ( "$alphaDir/common/DARK_TDRSALESUM_$yyyy*.csv" ) )[ 0 ];
if ( !$alphaReconFileName || !$alphaTDRSFileName ) {
	print STDERR "ERROR : POFEERECONSUM and/or TDRSALESUM file missing from current Alpha folder [$alphaDir]\n";
	exit 1;
}

$currReconFile = new PoFeeReconSumm ( file => $alphaReconFileName );
$currQtyMap = Alpha::getTdrSalesSumQtys ( $alphaTDRSFileName , $alphaDarkTDRSFileName );

$alphaReconFileName = ( glob ( "$prevAlphaDir/common/POFEERECONSUM_$prevYYYY*.csv" ) )[ 0 ];
$alphaTDRSFileName = ( glob ( "$prevAlphaDir/common/TDRSALESUM_$prevYYYY*.csv" ) )[ 0 ];
$alphaDarkTDRSFileName = ( glob ( "$prevAlphaDir/common/DARK_TDRSALESUM_$prevYYYY*.csv" ) )[ 0 ];
if ( !$alphaReconFileName || !$alphaTDRSFileName ) {
	print STDERR "ERROR : POFEERECONSUM and/or TDRSALESUM file missing from previous Alpha folder [$prevAlphaDir]\n";
	exit 1;
}

$prevReconFile = new PoFeeReconSumm ( file => $alphaReconFileName );
$prevQtyMap = Alpha::getTdrSalesSumQtys ( $alphaTDRSFileName , $alphaDarkTDRSFileName );

print "\n";
print "TSX ALPHA TRADE FEE RECONCILIATION\n\n";
showProducts ( $thisDispMon , $prevDispMon , $currReconFile , $prevReconFile , $currQtyMap , $prevQtyMap , \%AlphaProdMap::subProdMap );
print "\n";