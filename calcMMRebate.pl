#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use POSIX qw ( strftime );

use File::Basename;
use lib dirname $0;

use Billing::AlphaTdrSaleSumm;
use Billing::AlphaProdMap;

my $scriptName = basename $0;

sub usageAndExit {
	print STDERR "Usage : " , $scriptName , " -m yyyymm -p PO -t MMId[,MMId...] -r billingFileDir\n";
	exit 1;
}

sub addQtyToMap {
	my ( $map , $qty , $key1 , $key2 , $key3 , $noTotal ) = @_;
	$$map{ $key1 }{ $key2 }{ $key3 } += $qty;
	if ( !$noTotal ) {
		$$map{ $key1 }{ "TOTAL" }{ $key3 } += $qty;
		$$map{ "TOTAL" }{ "TOTAL" }{ $key3 } += $qty;
	}
}

sub transformQty {
	my ( $sym , $qty ) = @_;
	if ( $sym =~ /\.(NT|DB)(\.|$)/ ) {
		$qty /= 100;
	}
	return $qty;
}

# Parse the cmd line.
# -------------------
my ( $yyyymm , $po , $mmIds , $rootDir );

GetOptions ( 
	'm=s'	=> \$yyyymm ,
	'p=s'	=> \$po ,
	't=s'	=> \$mmIds ,
	"r=s"	=> \$rootDir
) or usageAndExit;

usageAndExit if ( ( !$yyyymm || $yyyymm !~ /^201\d(0[1-9]|1[012])$/ ) || !$po || !$mmIds || !$rootDir );

my %mmIdMap = map { $_ => 1 } split ( /,/ , $mmIds );
my ( $yyyy , $mm ) = ( $yyyymm =~ /(....)(..)/ );
my $dispDate = strftime ( "%B %Y" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );

$rootDir =~ s/ /\\ /g;
my $alphaDir = ( glob ( $rootDir . "/$yyyy-$mm" ) )[ 0 ];
if ( !$alphaDir ) {
	print STDERR "Error : could not find Alpha folder matching [$yyyymm] in root [$rootDir]\n";
	exit 1;
}
$alphaDir =~ s/ /\\ /g;

# Make a SubProduct => Product map.
# ---------------------------------
my %productMap = ();

foreach my $product ( keys %AlphaProdMap::subProdMap ) {
	foreach my $subProduct ( @{ $AlphaProdMap::subProdMap{ $product } } ) {
		$productMap{ $subProduct } = $product;
	}
}

print "Volumes and Fees by Product : $dispDate\n";
print "Market Makers : " , join ( "; " , sort keys %mmIdMap ) , "\n\n";
print "Product,SubProduct,Total Vol,Total Fees,MM Vol,MM Fees,Fee Diff\n";

# Get the fees/volumes and partition them by TraderID and subproduct.
# -------------------------------------------------------------------
my %feeByProduct = ();
my %volByProduct = ();
my %feeByMM = ();
my %volByMM = ();

my $tssFile = new AlphaTdrSaleSumm ( file => [ glob ( "$alphaDir/common/TDRSALESUM_*.csv" ) , 
											glob ( "$alphaDir/common/DARK_TDRSALESUM_*.csv" ) ]
								);

# Grab only records with the correct PO.
# --------------------------------------
foreach my $keys (
	grep {
		$$_{ "PO" } == $po
	} @{ $tssFile->allKeys () }
) {
	my $trdrID = $$keys{ "Trader ID" };
	my $subProd = $$keys{ "SUB-PRODUCT" };
	my $sym = $$keys{ "SYMBOL" };
	my $qty = $tssFile->val ( $keys , "VOLUME" );
	my $fee = $tssFile->val ( $keys , "NET FEE" );

	$qty = transformQty ( $sym , $qty );
	
#	Special case - avoid double counting AOD Rebate..
#	-------------------------------------------------
	$qty = 0 if $subProd eq 'V_AOD_REBATE';	
	
	my $product = $productMap{ $subProd };
	if ( !$product ) {
		print STDERR "WARNING : Unknown product for subproduct [$subProd].\n";
		$product = "UNKNOWN";
	}

	addQtyToMap ( \%volByProduct , $qty , $product , $subProd , "TOTAL" );
	addQtyToMap ( \%feeByProduct , $fee , $product , $subProd , "TOTAL" );
				
	if ( exists $mmIdMap{ $trdrID } ) {
		addQtyToMap ( \%volByProduct , $qty , $product , $subProd , $trdrID );
		addQtyToMap ( \%feeByProduct , $fee , $product , $subProd , $trdrID );
			
		addQtyToMap ( \%volByMM , $qty , $trdrID , $product , $subProd );
		addQtyToMap ( \%feeByMM , $fee , $trdrID , $product , $subProd );
	}
}

foreach my $product ( ( sort ( grep { ! /TOTAL/ } keys %feeByProduct ) ) , "TOTAL" ) {
	foreach my $subProduct ( ( sort ( grep { ! /TOTAL/ } keys %{ $feeByProduct{ $product } } ) ) , "TOTAL" ) {
		my ( $mmFee , $mmVol ) = ( 0 , 0 );
		foreach my $mmId ( grep { ! /TOTAL/ } keys %{ $feeByProduct{ $product }{ $subProduct } } ) {
			$mmVol += $volByProduct{ $product }{ $subProduct }{ $mmId };		
			$mmFee += $feeByProduct{ $product }{ $subProduct }{ $mmId };
		}
		my $totVol = $volByProduct{ $product }{ $subProduct }{ "TOTAL" };
		my $totFee = $feeByProduct{ $product }{ $subProduct }{ "TOTAL" };
		# --- A_ prefixed to subproduct for backward compatibility ---
		my $dispSubProd = $subProduct ; $dispSubProd =~ s/^/A_/ if $subProduct ne "TOTAL";
		printf "$product,$dispSubProd,%.0f,%.2f,%.0f,%.2f,%.2f\n" , $totVol , $totFee , $mmVol , $mmFee , ( $totFee - $mmFee );

	}
}

print "\n\n";

print "Market Maker Volumes and Fees by Product\n";
print "MM,Product,SubProduct,Vol,Fees\n";
foreach my $mmId ( sort ( grep { ! /TOTAL/ } keys %feeByMM ) ) {
	foreach my $product ( sort ( grep { ! /TOTAL/ } keys %{ $feeByMM{ $mmId } } ) ) {
		foreach my $subProduct ( sort ( grep { ! /TOTAL/ } keys %{ $feeByMM{ $mmId }{ $product } } ) ) {
			# --- A_ prefixed to subproduct for backward compatibility ---
			( my $dispSubProd = $subProduct ) =~ s/^/A_/;
			printf "$mmId,$product,$dispSubProd,%.0f,%.2f\n" , 
					$volByMM{ $mmId }{ $product }{ $subProduct } , 
					$feeByMM{ $mmId }{ $product }{ $subProduct };
		}
	}
}

