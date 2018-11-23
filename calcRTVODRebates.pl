#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use POSIX qw ( strftime );
use Time::Local;


use File::Basename;
use lib dirname $0;
use CSV;

my $scriptName = basename $0;

sub usageAndExit {
	print STDERR "Usage : " , $scriptName , " -m yyyymm -r billingFileDir -v VODFile\n";
	exit 1;
}

sub lastDayOfMonth {
	my ( $yyyy , $mm ) = @_;	# --- 20xx, 1-12 (month is one-based, here) ---
	$mm++;
	if ( $mm > 12 ) {
		$yyyy++;
		$mm -= 12;
	}
	my $dd;
	my $time = timelocal ( 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );
	$time -= 86400;
	( $dd , $mm , $yyyy ) = ( localtime ( $time ) )[ 3 .. 5 ];
	return sprintf "%02d/%02d/%4d" , $mm + 1 , $dd , $yyyy + 1900;
}

sub camelCase {
	my ( $str ) = @_;
	
	$str = lc $str;
	$str =~ s/(^|\W)(.)/$1 . uc($2)/ge;
	return $str;
}

# Parse the cmd line.
# -------------------
my ( $yyyymm , $vodFile , $rootDir );

GetOptions ( 
	'm=s'	=> \$yyyymm ,
	'v=s'	=> \$vodFile ,
	"r=s"	=> \$rootDir
) or usageAndExit;

usageAndExit if ( ( !$yyyymm || $yyyymm !~ /^201\d(0[1-9]|1[012])$/ ) || !$vodFile || !$rootDir );

my ( $yyyy , $mm ) = ( $yyyymm =~ /(....)(..)/ );
my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );

my $dispDate = strftime ( "%B %Y" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );

my $commonDir = ( glob ( $rootDir . "/??-$mmm-$yyyy/common" ) )[ 0 ];
if ( !$commonDir ) {
	print STDERR "Error : could not find folder matching [$yyyymm] in root [$rootDir]\n";
	exit 1;
}

# Grab the VOD file.
# ------------------
my %vodMap = ();

$vodFile =~ s/(\s)/\\$1/g;
open VOD , glob ( $vodFile ) or die "Cannot open VOD file [$vodFile] : $!";
# <VOD>;
while ( <VOD> ) {

	chomp;
	my $rec = CSV::parseRec ( $_ );
#	my $po = $$rec[ 16 ];
	my $po = $$rec[ 25 ];
#	( my $po = $$rec[ 24 ] ) =~ s/^.*\((\d+)\)$/$1/ ; $po = sprintf "%d" , $po;
#	my $po = $$rec[ 2 ];
	if ( $po ) {	# --- filter out unassigned securities ---
		$vodMap{ $po }++;
	}
}
close VOD;

# Grab the RT rebate info.
# ------------------------
my %poNameMap = ();
my %rtRebateMap = ();

open POFEE , ( glob ( "$commonDir/pofeereconsum_$yyyy*.csv" ) )[ 0 ]
	or die "Cannot open PO fee recon file in $commonDir : $!";
	
# Skip down to the section containing RT Rebate info.
# ---------------------------------------------------
while ( <POFEE> ) {
	last if /BROKER NUMBER/;
}
while ( <POFEE> ) {

	chomp;
	
	my $rec = CSV::parseRec ( $_ );
	my ( $po , $poName , $rtRebate ) = ( @$rec[ 0 , 1 , 5 ] );
	last if $po =~ /^\s*$/;

#	my ( $po , $poName , $rtRebate ) = /^(\d+),"(.*?)",[^,]+,[^,]+,[^,]+,([^,]+)/;
	
	$poNameMap{ $po } = "\"$poName\"";
	if ( $rtRebate != 0 ) {
		$rtRebateMap{ $po } = $rtRebate * -1;
	}
}

close POFEE;

# Print out the results.
# ----------------------
my $date = lastDayOfMonth ( $yyyy , $mm );

print "\"Name: 9 & 11 - RT & VOD SYMBOL CREDITS (AMOUNTS WITHOUT TAX)\"\n";
print "Date: $dispDate\n\n";

print "Document Date,Broker #, Client Name, Client Detail (to be printed on invoice/cheque),SOP Type, Credit Amount\n";
my $totQty = 0;
my $totRT = 0;
foreach my $po ( sort { $a <=> $b } keys %rtRebateMap ) {
	my $rtRebate = $rtRebateMap{ $po };
	printf "$date,$po,$poNameMap{ $po },RT REBATE,RT,%.2f\n" , $rtRebate;
	$totRT += $rtRebate;
}
printf "Total RT,,,,Total RT,%.2f\n" , $totRT;

$totQty += $totRT;

my $totVOD = 0;
my $vodMult = 40;
foreach my $po ( sort { $a <=> $b } keys %vodMap ) {
	my $vodCnt = $vodMap{ $po };
	my $vodRebate = $vodCnt * $vodMult;
	printf "$date,$po,$poNameMap{ $po },VOD FIXED SYMBOL CREDIT $vodCnt SYMBOLS,VOD,%.2f\n" , $vodRebate;
	$totVOD += $vodRebate;
}

$totQty += $totVOD;

printf "Total VOD,,,,Total VOD,%.2f\n" , $totVOD;

printf ",,,,Total Amount,%.2f\n" , $totQty;