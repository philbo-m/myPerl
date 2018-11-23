#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use CSV;
use Data::Dumper;

sub getRTTotals {
	my ( $po , $file , $rtTotalMap ) = @_;
	open FILE , $file or die "Cannot open PO fee summary file [$file]: $!";
	
	while ( <FILE> ) {
		chomp;
		my @flds = map { s/"//g ; $_ } split /,/;
		
		if ( $flds[ 0 ] =~ /^"?.+ Sub-Total/ ) {
			$$rtTotalMap{ $po }+= $flds[ 4 ];
		}
	}
	
	close FILE;
}

sub passThru {
	my ( $recs ) = @_;
	foreach my $rec ( @$recs ) {
		print CSV::fldsToRec ( $rec ) , "\n";
	}
}

sub processPORecs {
	my ( $recs , $rtTotalMap ) = @_;
	
	my ( $rtGrandTrdTotal , $rt100TrdTotal ) = ( 0 , 0 );
	
	foreach my $rec ( @$recs ) {
		my $po = $$rec[ 0 ];
		if ( $po eq "BROKER NUMBER" ) {
			push @$rec , "RT TRADING CREDIT";
		}
		elsif ( $po eq '' ) {
			my $poDesc = $$rec[ 1 ];
			if ( $poDesc eq "Total" ) {
				push @$rec , $rtGrandTrdTotal;
			}
			elsif ( $poDesc eq "Total(w/o Brokers 1 and 100)" ) {
				push @$rec , $rtGrandTrdTotal - $rt100TrdTotal;
			}
		}
		else {
			my $rtTotal = $$rtTotalMap{ $po };
			$rtGrandTrdTotal += $rtTotal;
			if ( $po eq '100' ) {
				$rt100TrdTotal = $rtTotal;
			}
			push @$rec , $rtTotal;
		}
				
		print CSV::fldsToRec ( $rec ) , "\n";
	}
}		

sub processProductRecs {
	my ( $recs ) = @_;
	
	my %RTCodes = map { $_ => 1 } qw ( TF7700 TF7720 TF7750 );
	my @RTRecs = ();
	my %totFeeMap = ();
	
	foreach my $rec ( @$recs ) {
		my ( $prodCode , $prodDesc , $fee , $feeWithout100 ) = @$rec;
		
		if ( exists $RTCodes{ $prodCode } ) {
			push @RTRecs , $rec;
			$totFeeMap{ "RT" }{ "TOT" } += $fee;
			$totFeeMap{ "RT" }{ "NOT 100" } += $feeWithout100;
		}
		elsif ( $prodCode eq 'Grand Total Fee' ) {
			print join ( "," , $prodCode , "" , $totFeeMap{ "NON-RT" }{ "TOT" } , $totFeeMap{ "NON-RT" }{ "NOT 100" } ) , "\n";
		}
		else {
			print join ( "," , @$rec ) , "\n";
			$totFeeMap{ "NON-RT" }{ "TOT" } += $fee;
			$totFeeMap{ "NON-RT" }{ "NOT 100" } += $feeWithout100;
		}
	}
	
	print "\n";
	foreach my $RTRec ( @RTRecs ) {
		print join ( "," , @$RTRec ) , "\n";
	}
	print join ( "," , "" , "Total RT Trading Credit" , $totFeeMap{ "RT" }{ "TOT" } , $totFeeMap{ "RT" }{ "NOT 100" } ) , "\n";
}


# Grab the relevant totals from the POs' files.
# ---------------------------------------------
my %rtTotalMap = ();

my $commonDir = dirname ( $ARGV[ 0 ] );
my $poBaseDir = ( $commonDir eq "." ? ".." : dirname ( $commonDir ) );

foreach my $poDir ( glob "$poBaseDir/po/*" ) {
	my $poFeeFile = ( glob ( "$poDir/fee_sum*.csv" ) )[ 0 ];
	getRTTotals ( basename ( $poDir ) + 0 , $poFeeFile , \%rtTotalMap );
}

# Go thru the POFeeReconSum file itself.
# --------------------------------------
local $/ = undef;	# --- grab the entire file ---
my $recs = <>;

$recs = CSV::parseRecs ( $recs );
my @recBuf = ();

foreach my $rec ( @$recs ) {
	my $firstFld = $$rec[ 0 ];
	if ( $firstFld eq "BROKER NUMBER" ) {
		passThru ( \@recBuf );
		@recBuf = ();
	}
	elsif ( $firstFld eq "ELP Rebate" ) {
		processPORecs ( \@recBuf , \%rtTotalMap );
		@recBuf = ();
	}
	elsif ( $firstFld eq "PRODUCT IDs" ) {
		passThru ( \@recBuf );
		@recBuf = ();
	}
	
	push @recBuf , $rec;
}

processProductRecs ( \@recBuf );
		
		
