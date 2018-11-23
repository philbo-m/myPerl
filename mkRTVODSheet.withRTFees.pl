#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use File::Basename;
use POSIX qw ( strftime );
my $scriptName = basename $0;

use lib dirname $0;

use Util;
use Billing::PoFeeReconSumm;
use Billing::RTTraderSymCredit;
use Billing::FeeSumm;

sub usageAndExit {
	print STDERR "Usage : $scriptName -m yyyymm -t templateFile -p poRefFile -r billingFileDir -v vodSymCreditFile -f RTFeeFile\n";
	exit 1;
}

my ( $rootDir , $vodFile , $rtFeeFile , $poRefFile , $tmplFile );
my $yyyymm = join ( "" , Util::prevMonth );

GetOptions ( 
	'm=s'	=> \$yyyymm ,
	"r=s"	=> \$rootDir ,
	'v=s'	=> \$vodFile ,
	'f=s'	=> \$rtFeeFile ,
	'p=s'	=> \$poRefFile ,
	't=s'	=> \$tmplFile
) or usageAndExit;

usageAndExit if ( ( !$yyyymm || $yyyymm !~ /^201\d(0[1-9]|1[012])$/ ) || !$rootDir || !$vodFile || !$rtFeeFile || !$tmplFile || !$poRefFile );

my ( $yyyy , $mm ) = ( $yyyymm =~ /(....)(..)/ );
my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );
my $dispDate = strftime ( "%B %Y" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );
my $lastDay = Util::lastDayOfMonth ( $yyyy , $mm );				# --- MM/DD/YYYY ---
( my $batchLastDay = $lastDay ) =~ s/(..)\/(..)\/..(..)/$1$2$3/;	# --- MMDDYY ---

my $tmxDir = ( glob ( $rootDir . "/??-$mmm-$yyyy" ) )[ 0 ];

my %poFeeMap = ();

# Get RT and VOD Trading fees/credits/rebates from individual POs' FEE_SUM files.
# -------------------------------------------------------------------------------
my %feeNameMap = (
	"RT Sub-Total"					=> "TSX RT TRADING" ,
	"RT Symbol Credit Sub-Total"	=> "TSX RT SYMBOLS OF RESPONSIBILITY" ,
	"VOD Sub-Total"					=> "TSXV VOD TRADING"
);

my $poBaseDir = "$tmxDir/po";
foreach my $poDir ( glob "$poBaseDir/???" ) {
	my $po = basename ( $poDir ) + 0;
	print STDERR "...[$poDir] [$po]...\n";
	my $poFeeFile = ( glob ( "$poDir/fee_sum*.csv" ) )[ 0 ];
	if ( !$poFeeFile ) {
		print STDERR "No Fee Summary file in [$poDir]...\n";
		next;
	}
	my $poFee = new FeeSumm ( file => $poFeeFile , includeTotals => 1 );
	foreach my $key ( keys %feeNameMap ) {
		my $val = $poFee->productNetFee ( $key );
		if ( $val != 0 ) {
			$poFeeMap{ $po }{ $feeNameMap{ $key } } = $val;
		}
	}
}	

# Get VOD Symbol Credits from CSV file supplied by Trading Services (Vic C).
# --------------------------------------------------------------------------
# $vodFile =~ s/(\s)/\\$1/g;
$vodFile = "\"${vodFile}\"";
open VOD , glob ( $vodFile ) or die "Cannot open VOD Symbol Credit file [$vodFile] : $!";
# <VOD>;	# --- UNCOMMENT THIS IF THE VOD SYM CREDIT FILE HAS A HEADER RECORD ---
while ( <VOD> ) {

	chomp;
	my $rec = CSV::parseRec ( $_ );
#	my $po = $$rec[ 2 ] ; $po = sprintf "%d" , $po;
#	my $po = $$rec[ 16 ];
#	my $po = $$rec[ 25 ];
#	my $po = $$rec[ 26 ];
	( my $po = $$rec[ 25 ] ) =~ s/^.*\((\d+)\)$/$1/ ; $po = sprintf "%d" , $po;
#	( my $po = $$rec[ 2 ] ) =~ s/^.*\((\d+)\)$/$1/ ; $po = sprintf "%d" , $po;
#	my $po = $$rec[ 2 ];
	if ( $po ) {	# --- filter out unassigned securities ---
		$poFeeMap{ $po }{ "VOD FIXED SYMBOL CREDIT" }++;
	}
}
close VOD;

# Get RT Fees from CSV file also supplied by Trading Services (Vic C).
# --------------------------------------------------------------------
# $rtFeeFile =~ s/(\s)/\\$1/g;
$rtFeeFile = "\"${rtFeeFile}\"";

open RTFEE , glob ( $rtFeeFile ) or die "Cannot open RT Fee file [$rtFeeFile] : $!";
while ( <RTFEE> ) {
	chomp;
	my $rec = CSV::parseRec ( $_ );
	my ( $po , $qty ) = ( $$rec[ 1 ] , $$rec[ 3 ] );
	next if ( $po !~ /^\d+$/ || $qty !~ /^\d+$/ );
	
	$poFeeMap{ $po }{ "TSX REGISTERED TRADER FEE" } = $qty;
}
close RTFEE;

# Get PO information from the reference file.
# -------------------------------------------
my %poRefMap = ();

$poRefFile =~ s/(\s)/\\$1/g;
open POREF , glob ( $poRefFile ) or die "Cannot open PO Reference file [$poRefFile] : $!";
while ( <POREF> ) {
	chomp;
	my $rec = CSV::parseRec ( $_ );
	$poRefMap{ $$rec[ 0 ] }{ NAME } = $$rec[ 1 ];
	$poRefMap{ $$rec[ 0 ] }{ ID } = $$rec[ 2 ];
	$poRefMap{ $$rec[ 0 ] }{ PADSCDS } = $$rec[ 3 ];
	$poRefMap{ $$rec[ 0 ] }{ CUID } = $$rec[ 4 ];
	
	( $poRefMap{ $$rec[ 0 ] }{ ADDRCODE } = $$rec[ 2 ] ) =~ s/^.*-//;
}
close POREF;

# Now put it all together using the template file.
# ------------------------------------------------
open TMPL , $tmplFile or die "Cannot open template file [$tmplFile] : $!";
while ( <TMPL> ) {
	s/#MMMM YYYY#/$dispDate/;
	print;
	last if /BatchNumber/;
}

while ( <TMPL> ) {
	chomp;
	my ( $type , $batchNo, undef , undef , undef , undef , undef , $prodID , 
			$siteID , undef , $unitPrice , undef , $typeID , $paymentTerms , $currency , $prodDesc ,
			undef , undef , undef , undef , undef , undef , undef , $company ) = split /,/;
	$batchNo =~ s/#.*#/$batchLastDay/;	
	
#	print STDERR "[$_] [$prodDesc] [$prodID] [$unitPrice]...\n";
	my $dispDesc = $prodDesc;
	my $sumVal = 0;
	foreach my $po ( sort { $a <=> $b } keys %poFeeMap ) {
		my $val = $poFeeMap{ $po }{ $prodDesc };
		my ( $qty , $prc );
		next if !$val;
		if ( $prodDesc eq 'VOD FIXED SYMBOL CREDIT' ) {
			$dispDesc = "$prodDesc $val SYMBOLS";
			$qty = -1;
			$prc = $unitPrice * $val;
		}
		elsif ( $prodDesc eq 'TSX REGISTERED TRADER FEE' ) {
			$prc = $unitPrice;
			$qty = $val;
		}
		elsif ( $prodDesc =~ /^(TSX RT|TSXV VOD) TRADING$/ ) {
			my $mult = ( $val < 0 ? -1 : 1 );
			$prc = $val * $mult;
			$qty = $mult;
				
		}
		else {
		
			$prc = ( $val > 0 ? $val : $val * -1 );
			$qty = -1;
		}
		$poFeeMap{ $po }{ TOTAL_FEE } += $qty * $prc;
		$poFeeMap{ TOTAL }{ TOTAL_FEE } += $qty * $prc;
		
		printf "%s,%s,%s,%s,%s,%s,%s,%s" , 
				$type , $batchNo , $poRefMap{ $po }{ NAME } , $poRefMap{ $po }{ ID } , $poRefMap{ $po }{ ADDRCODE } , "" , $lastDay , $prodID;
		printf ",%s,%d,%.2f,%.2f,%s,%s,%s,%s" ,
				$siteID , $qty , $prc , $qty * $prc , $typeID , $paymentTerms , $currency , $dispDesc;
		printf ",%s,%s,%s,%s,%s,%s,%s,%s\n" ,
				"" , $poRefMap{ $po }{ PADSCDS } , $poRefMap{ $po }{ CUID } , "" , "" , "" , "" , $company;
	}
	print "\n";
}
close TMPL;

print "\n";
print "Credits by Customer\n";

print "CustomerName,CustomerID,Total\n";
foreach my $po ( sort keys %poRefMap ) {
	my $totFee = $poFeeMap{ $po }{ TOTAL_FEE };
	next if !$totFee;
	printf "%s,%s,%.2f\n" , 
			$poRefMap{ $po }{ NAME } , $poRefMap{ $po }{ ID } , $totFee;
}
printf "%s,%s,%.2f\n" , "GRAND TOTAL" , "" , $poFeeMap{ TOTAL }{ TOTAL_FEE };
