#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use POSIX qw ( strftime );

use File::Basename;
use lib dirname $0;

use Billing::TraderDetail;
use Billing::TSXProdMap;

my $scriptName = basename $0;

sub usageAndExit {
	print STDERR "Usage : " , $scriptName , " -m yyyymm -p PO -t MMId[,MMId...] -r billingFileDir\n";
	exit 1;
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

$po = sprintf ( "%03d" , $po );
my @mmIds = split ( /,/ , $mmIds );
my ( $yyyy , $mm ) = ( $yyyymm =~ /(....)(..)/ );
my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );

my $dispDate = strftime ( "%B %Y" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );

$rootDir =~ s/ /\\ /g;
my $tmxDir = ( glob ( $rootDir . "/??-$mmm-$yyyy" ) )[ 0 ];
if ( !$tmxDir ) {
	print STDERR "Error : could not find TMX folder matching [$yyyymm] in root [$rootDir]\n";
	exit 1;
}
$tmxDir =~ s/ /\\ /g;

# Make a SubProduct => Product map.
# ---------------------------------
my %productMap = ();

foreach my $product ( keys %TSXProdMap::subProdMap ) {
	foreach my $subProduct ( @{ $TSXProdMap::subProdMap{ $product } } ) {
		$productMap{ $subProduct } = $product;
	}
}

# Get the fees/volumes and partition them by TraderID and subproduct.
# -------------------------------------------------------------------
my $tdFile = new TraderDetail ( file => [ glob ( "$tmxDir/po/$po/trader_detail_clob*.csv" ) , 
											glob ( "$tmxDir/po/$po/trader_detail_nonclob*.csv" ) ]
								);

my $subProds = $tdFile->keys ( 'PRODUCT' );

# Filter out all RT/VOD subproducts as these are already in their own invoice.
# Also sort them by Product and by name.
# ----------------------------------------------------------------------------
@$subProds = grep { $_ !~ /_(RT|VOD)/ } @$subProds;
@$subProds = sort { ( $productMap{ $a } cmp $productMap{ $b } ) || ( $a cmp $b ) } @$subProds;

print "TSX/TSXV Volumes and Fees by Subproduct : $dispDate\n";
print "TraderIDs : " , join ( "; " , sort @mmIds ) , "\n";
print "Contains details only of subproducts with trading activity by the above TraderIDs.\n\n";

my ( $allTotVol , $allGrandTotVol , $allTotFee , $allGrandTotFee , $mmTotVol , $mmTotFee );

print "Product,Subproduct,Total Volume,Total Fees,MM Volume,MM Fees,Fee Diff\n";
foreach my $subProd ( @$subProds ) {

	my $product = $productMap{ $subProd };
	if ( !$product ) {
		print STDERR "WARNING : Unknown product for subproduct [$subProd].\n";
	}
	my $allVol = $tdFile->subProdVol ( $subProd );
	my $allFee = $tdFile->subProdNetFee ( $subProd );
	$allGrandTotVol += $allVol;
	$allGrandTotFee += $allFee;
	
	my ( $mmVol , $mmFee );
	foreach my $trdrID ( @mmIds ) {
		$mmVol += $tdFile->val ( { TRADER_ID => $trdrID , PRODUCT => $subProd } , "TOTAL_VOLUME" );
		$mmFee += $tdFile->val ( { TRADER_ID => $trdrID , PRODUCT => $subProd } , "NET_FEE" );
	}
	next if $mmVol == 0;
	
	$allTotVol += $allVol;
	$allTotFee += $allFee;
	$mmTotVol += $mmVol;
	$mmTotFee += $mmFee;
	
	printf "$productMap{ $subProd },$subProd,%.0f,%.2f,%.0f,%.2f,%.2f\n" , $allVol , $allFee , $mmVol , $mmFee , ( $allFee - $mmFee );
}
printf "TOTAL,,%.0f,%.2f,%.0f,%.2f,%.2f\n" , $allTotVol , $allTotFee , $mmTotVol , $mmTotFee , ( $allTotFee - $mmTotFee );
print "\n";
printf "TOTAL - ALL SUBPRODUCTS,,%.0f,%.2f\n" , $allGrandTotVol , $allGrandTotFee;

print "\n";

print "TraderID Volumes and Fees by Subproduct\n";
print "TraderID,Product,Subproduct,Volume,Fees\n";

foreach my $trdrID ( sort @mmIds ) {
	foreach my $subProd ( @$subProds ) {
		my $mmVol = $tdFile->val ( { TRADER_ID => $trdrID , PRODUCT => $subProd } , "TOTAL_VOLUME" );
		next if $mmVol == 0;
		
		my $mmFee = $tdFile->val ( { TRADER_ID => $trdrID , PRODUCT => $subProd } , "NET_FEE" );
					
		printf "$trdrID,$productMap{ $subProd },$subProd,%.0f,%.2f\n" , $mmVol , $mmFee;
	}
}
printf "TOTAL,,,%.0f,%.2f\n" , $mmTotVol , $mmTotFee;