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
use Select;
use Billing::TSXProdMap;
use Billing::AlphaProdMap;

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
	my ( $thisDispMon , $prevDispMon , $currFeeMap , $prevFeeMap ) = @_;

#	Fee Maps are : product -> "FEE" -> fee
#	                       -> "IDX" -> index (so we can preserve original sort order)
#	---------------------------------------------------------------------------------
	print "MSGP PRODUCT DESCRIPTION," ,
			"TOTAL FEE CURRENT MONTH ($thisDispMon),TOTAL FEE PREVIOUS MONTH ($prevDispMon),% CHANGE\n";
	
	my ( $currTot , $prevTot );
	foreach my $product ( sort { 
							$$currFeeMap{ $a }{ "IDX" } <=> $$currFeeMap{ $b }{ "IDX" } 
							|| $$currFeeMap{ $a }{ "IDX" } cmp $$currFeeMap{ $b }{ "IDX" }
						} keys %$currFeeMap ) {
		
		my $currFee = $$currFeeMap{ $product }{ "FEE" };
		$currTot += $currFee;
		my $prevFee = $$prevFeeMap{ $product }{ "FEE" };	
		$prevTot += $prevFee;
		printf "$product,%.2f,%.2f,%.3f\n" , $currFee , $prevFee , mkPctChg ( $currFee , $prevFee );
	}
	printf "Grand Total Fee,%.2f,%.2f,%.3f\n" , $currTot , $prevTot , mkPctChg ( $currTot , $prevTot );
}

sub showProductsXXX {
	my ( $thisDispMon , $prevDispMon , $currFeeFile , $prevFeeFile ) = @_;

#	Fee Maps are : product -> "FEE" -> fee
#	                       -> "IDX" -> index (so we can preserve original sort order)
#	---------------------------------------------------------------------------------
	print "MSGP PRODUCT DESCRIPTION,TOTAL FEE CURRENT MONTH ($thisDispMon),TOTAL FEE PREVIOUS MONTH ($prevDispMon),% CHANGE\n";
	
	my ( $currTot , $prevTot );

	foreach my $rec ( @{ $currFeeFile->{prodRecs} } ) {
		my $product = $$rec[ 1 ];
		my $currFee = $$rec[ 2 ];
		$currTot += $currFee;
		
		my $prevFee = $prevFeeFile->{prodSection}->val ( { "MSGP PRODUCT DESCRIPTION" => $product } , "TOTAL FEE" );
		$prevTot += $prevFee;

		printf "$product,%.2f,%.2f,%.3f\n" , $currFee , $prevFee , mkPctChg ( $currFee , $prevFee );
	}
	printf "Grand Total Fee,%.2f,%.2f,%.3f\n" , $currTot , $prevTot , mkPctChg ( $currTot , $prevTot );
}

sub showTotVols {
	my ( $currFeeMap , $prevFeeMap , $isDblCounted ) = @_;
	
	my ( $currTot , $prevTot ) = ( 0 , 0 );
	foreach my $po ( keys %$currFeeMap ) {
		foreach my $subProduct ( keys %{ $$currFeeMap{ $po } } ) {
			$currTot += $$currFeeMap{ $po }{ $subProduct }{ "VOL" };
		}
	}
	foreach my $po ( keys %$prevFeeMap ) {
		foreach my $subProduct ( keys %{ $$prevFeeMap{ $po } } ) {
			$prevTot += $$prevFeeMap{ $po }{ $subProduct }{ "VOL" };
		}
	}
	
	if ( $isDblCounted ) {
		$currTot /= 2 ; $prevTot /= 2;
	}
	printf "Total Volume,%.0f,%.0f,%.3f\n" , $currTot , $prevTot , mkPctChg ( $currTot , $prevTot );
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
my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );

my $dispDate = strftime ( "%B %Y" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );

my $tmxDir = ( glob ( $rootDir . "/??-$mmm-$yyyy/common" ) )[ 0 ];
my $selectDir = ( glob ( $rootDir . "/TMXSelect/$yyyy-$mm/common" ) )[ 0 ];
my $alphaDir = ( glob ( $rootDir . "/Alpha/$yyyy-$mm/common" ) )[ 0 ];

if ( !$tmxDir ) {
	print STDERR "Error : could not find TMX folder matching [$yyyymm] in root [$rootDir]\n";
	exit 1;
}

# Grab the TMX files.

my $rootDateDir = TMX::getRootDateDir ( $rootDir , $yyyymm );

my $tmxFileName = ( glob ( "$rootDateDir/common/pofeereconsum_$yyyy*.csv" ) )[ 0 ];
my $selectFile = ( glob ( "$selectDir/POFEERECONSUM_$yyyy*.csv" ) )[ 0 ];
my $alphaFile = ( glob ( "$alphaDir/POFEERECONSUM_$yyyy*.csv" ) )[ 0 ];

my $currTMXFile = new PoFeeReconSumm ( file => $tmxFileName );
my $currTMXFeeMap = TMX::getFeesAndRebates ( $rootDir , $yyyy , $mm );
my $currTMXVolMap = TMX::getVolumes ( $rootDir , $yyyy , $mm );
my $currSelectFeeMap = Select::getVolsAndFees ( "$rootDir/TMXSelect" , $yyyy , $mm );
my $currSelectFeeSummMap = Select::getFeeSumm ( "$rootDir/TMXSelect" , $yyyy , $mm );
my $currAlphaFeeMap = Alpha::getVolsAndFees ( "$rootDir/Alpha" , $yyyy , $mm );
my $currAlphaFeeSummMap = Alpha::getFeeSumm ( "$rootDir/Alpha" , $yyyy , $mm );

my ( $prevYYYY , $prevMM ) = Util::prevMonth ( $yyyy , $mm );

my $prevRootDateDir = TMX::getRootDateDir ( $rootDir , sprintf ( "%04d%02d" , ${prevYYYY} , ${prevMM} ) );
my $prevTMXFileName = ( glob ( "$prevRootDateDir/common/pofeereconsum_$prevYYYY*.csv" ) )[ 0 ];
my $prevTMXFile = new PoFeeReconSumm ( file => $prevTMXFileName );

my $prevTMXFeeMap = TMX::getFeesAndRebates ( $rootDir , $prevYYYY , $prevMM );
my $prevTMXVolMap = TMX::getVolumes ( $rootDir , $prevYYYY , $prevMM );
my $prevSelectFeeMap = Select::getVolsAndFees ( "$rootDir/TMXSelect" , $prevYYYY , $prevMM );
my $prevSelectFeeSummMap = Select::getFeeSumm ( "$rootDir/TMXSelect" , $prevYYYY , $prevMM );
my $prevAlphaFeeMap = Alpha::getVolsAndFees ( "$rootDir/Alpha" , $prevYYYY , $prevMM );
my $prevAlphaFeeSummMap = Alpha::getFeeSumm ( "$rootDir/Alpha" , $prevYYYY , $prevMM );

my $thisDispMon = mkDateLabel ( $yyyy , $mm );
my $prevDispMon = mkDateLabel ( $prevYYYY , $prevMM );

print "MONTHLY TRADING FEE RECONCILIATION\n";
print "$thisDispMon vs. $prevDispMon\n\n";

print "EQUITY TRADE FEE RECONCILIATION\n\n";
showProducts ( $thisDispMon , $prevDispMon , $$currTMXFeeMap{ "PRODUCT" } , $$prevTMXFeeMap{ "PRODUCT" } );
# showProducts ( $thisDispMon , $prevDispMon , $currTMXFile , $prevTMXFile );
print "\n";

my ( $currTotRT , $prevTotRT , $currTotELP , $prevTotELP );
foreach my $po ( keys %{ $$currTMXFeeMap{ "PO" } } ) {
	$currTotRT += $$currTMXFeeMap{ "PO" }{ $po }{ "RTREBATE" };
	foreach my $elpEntry ( @{ $$currTMXFeeMap{ "PO" }{ $po }{ "ELPREBATE" } } ) {
		$currTotELP += $$elpEntry[ 1 ];
	}
}
foreach my $po ( keys %{ $$prevTMXFeeMap{ "PO" } } ) {
	$prevTotRT += $$prevTMXFeeMap{ "PO" }{ $po }{ "RTREBATE" };
	foreach my $elpEntry ( @{ $$prevTMXFeeMap{ "PO" }{ $po }{ "ELPREBATE" } } ) {
		$prevTotELP += $$elpEntry[ 1 ];
	}
}

my ( $currTotVol , $prevTotVol );
foreach my $po ( keys %$currTMXVolMap ) {
	$currTotVol += $$currTMXVolMap{ $po };
}
foreach my $po ( keys %$prevTMXVolMap ) {
	$prevTotVol += $$prevTMXVolMap{ $po };
}

printf "RT Rebate,%.2f,%.2f,%.3f\n" , $currTotRT , $prevTotRT , mkPctChg ( $currTotRT , $prevTotRT );
if ( $currTotELP || $prevTotELP ) {
	printf "ELP Rebate,%.2f,%.2f,%.3f\n" , $currTotELP , $prevTotELP , mkPctChg ( $currTotELP, $prevTotELP );
	print "\n";
}
printf "Total Volume,%.0f,%.0f,%.3f\n" , $currTotVol , $prevTotVol , mkPctChg ( $currTotVol , $prevTotVol );
print "\n\n";

print "TMX SELECT TRADE FEE RECONCILIATION\n\n";
showProducts ( $thisDispMon , $prevDispMon , $$currSelectFeeSummMap{ "PRODUCT" } , $$prevSelectFeeSummMap{ "PRODUCT" } );
print "\n";
showTotVols ( $currSelectFeeMap , $prevSelectFeeMap , 1 );
print "\n\n";

print "ALPHA TRADE FEE RECONCILIATION\n\n";
showProducts ( $thisDispMon , $prevDispMon , $$currAlphaFeeSummMap{ "PRODUCT" } , $$prevAlphaFeeSummMap{ "PRODUCT" } );
print "\n";
showTotVols ( $currAlphaFeeMap , $prevAlphaFeeMap , 1 );
