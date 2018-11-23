#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use CSV;

sub prcChgBucket {
	my ( $prcChg ) = @_;
	$prcChg * ( $prcChg < 0 ? -1 : 1 );
	
	my $bucket = ( $prcChg < 0.01 ? "0%-1%" :
					( $prcChg < 0.02 ? "1%-2%" :
						( $prcChg < 0.03 ? "2%-3%" : "> 3%" )
					)
				);
	return $bucket;
}

sub parseFile {
	my ( $file , $mocMap ) = @_;
	
	local $/;
	
	open FILE , $file or die "Cannot open MOC file [$file] : $!";
	my $fileCont = <FILE>;
	close FILE;

	my $recs = CSV::parseRecs ( $fileCont );
	foreach my $rec ( @$recs ) {
	
#		Rudimentary version awareness - columns added as of 30 Jan 2015.
#		----------------------------------------------------------------
		my ( $sym , $refPrice , $closePrice , $lsp , $mocVol , $contVol );
		if ( scalar @$rec == 18 ) {
			( $sym , $closePrice , $lsp , $mocVol , $contVol ) = ( @$rec[ 2 , 7 , 8 , 16 , 17 ] );
			$refPrice = "";
		}
		elsif ( scalar @$rec == 21 ) {
			( $sym , $refPrice , $closePrice , $lsp , $mocVol , $contVol ) = ( @$rec[ 2 , 7 , 8 , 9 , 17 , 18 ] );
		}
		
		next if ( $lsp !~ /^[\d. ]*$/ || $sym =~ /^\s*$/ );
		
#		--- Strip spaces out of flds ---
		$sym =~ s/\s+$//;
		$refPrice += 0 ; $closePrice += 0 ; $lsp += 0 ; $mocVol += 0 ; $contVol += 0;
		
		$$mocMap{ $sym }{ "LSP" } = ( $lsp == 0 ? $closePrice : $lsp );
		$$mocMap{ $sym }{ "VOL" } = $contVol;
	}
}
		
my ( %mocMap , %symMap ) = ( () , () );		

my $showVol = 1;

foreach my $mocFile ( @ARGV ) {
	my ( $date ) = ( $mocFile =~ /^(.*?)-.*\.csv/ );
	$date =~ s/^(\d\d)_(\d\d)_(\d\d\d\d)$/$3-$1-$2/;

	$mocMap{ $date } = {};
	parseFile ( $mocFile , $mocMap{ $date } );
	foreach my $sym ( keys %{ $mocMap{ $date } } ) {
		$symMap{ $sym } = 1;
	}
}

print join ( "," , "Symbol" , sort keys %mocMap ) , "\n";
			
foreach my $sym ( sort keys %symMap ) {
	print $sym;
	foreach my $date ( sort keys %mocMap ) {
		if ( $showVol ) {
			printf ",%d" , $mocMap{ $date }{ $sym }{ "VOL" };
		}
		else {
			printf ",%.3f" , $mocMap{ $date }{ $sym }{ "LSP" };
		}
	}
	print "\n";		
}
						
	