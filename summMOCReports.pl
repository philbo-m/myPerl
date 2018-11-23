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
		my ( $flip , $delay , $refPrice , $mocPrice , $lsp , $mocVol , $contVol );
		if ( scalar @$rec == 21 ) {
			( $flip , $delay , $refPrice , $mocPrice , $lsp , $mocVol , $contVol ) = ( @$rec[ 0 , 1 , 7 , 8 , 9 , 17 , 18 ] );
		}
		else {
			( $flip , $delay , $mocPrice , $lsp , $mocVol , $contVol ) = ( @$rec[ 0 , 1 , 7 , 8 , 16 , 17 ] );
			$refPrice = "";
		}
		
		next if $lsp !~ /^[\d. ]*$/;
		
		$delay =~ s/\s//g;
		$flip =~ s/\s//g;
		next if ( $mocVol + 0 == 0 && $delay eq '' );
		
		$$mocMap{ "COUNT" }++;
		$$mocMap{ "MOCVOL" } += $mocVol;
		$$mocMap{ "CONTVOL" } += $contVol;
		
		if ( $delay ) {
			$$mocMap{ "DELAY" }++;
		}
		if ( $flip ) {
			$$mocMap{ "FLIP" }++;
		}
		my $prcChg = ( $lsp + 0 ? ( $mocPrice - $lsp ) / $lsp : 0 );
		my $bucket = prcChgBucket ( $prcChg );
#		print "[$$rec[ 2 ]] [$delay] [[$$mocMap{ 'DELAY' }]] [$mocPrice] [$lsp] [[$bucket]] [$mocVol] [$contVol]\n";
		$$mocMap{ $bucket }++;
	}
}
		
my %mocMap = ();		

foreach my $mocFile ( @ARGV ) {
	my ( $date , $exch ) = ( $mocFile =~ /^(.*?)-.*(...)\.csv/ );
	$date =~ s/^(\d\d)_(\d\d)_(\d\d\d\d)$/$3-$1-$2/;

	$mocMap{ $date }{ $exch } = {};
	parseFile ( $mocFile , $mocMap{ $date }{ $exch } );
}

print join ( "," , "Date" , "Exchange" ,
					"MOC Syms" ,
					"MOC Vol" ,
					"Cont Vol" ,
					"Flipped" , 
					"Delayed" ,
					"0%-1%" , "1%-2%" , "2%-3%" , "> 3%"
			) , "\n";
			
foreach my $date ( sort keys %mocMap ) {
	
	foreach my $exch ( sort keys %{ $mocMap{ $date } } ) {
		my $mocDateExchMap = $mocMap{ $date }{ $exch };
		printf "$date,$exch,%d,%d,%d,%d,%d,%d,%d,%d,%d\n" ,
				$$mocDateExchMap{ "COUNT" } ,
				$$mocDateExchMap{ "MOCVOL" } ,
				$$mocDateExchMap{ "CONTVOL" } ,
				$$mocDateExchMap{ "FLIP" } ,
				$$mocDateExchMap{ "DELAY" } ,
				$$mocDateExchMap{ "0%-1%" } ,
				$$mocDateExchMap{ "1%-2%" } ,
				$$mocDateExchMap{ "2%-3%" } ,
				$$mocDateExchMap{ "> 3%" };
	}
}
						
	