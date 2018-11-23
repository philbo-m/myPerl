#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use File::Basename;
use Data::Dumper;

use UCrossBU;

my $progName = basename $0;

sub usageAndExit {
	print STDERR "Usage : " , $progName , " [-s] [-d] -b BUFile[,BUFile...]\n";
	print STDERR "Use '-s' to break down by subproduct.\n";
	print STDERR "Use '-d' to show details of inter-TraderID pairs.\n";
	print STDERR "BU assignments and rates are defined in one or more BUFiles.\n";
	exit 1;
}

my ( $useSubProduct , $showBothTrdrIDs , @BUFiles ); 
GetOptions ( 
	's'		=> \$useSubProduct ,
	'd'		=> \$showBothTrdrIDs ,
	'b=s'	=> \@BUFiles
) or usageAndExit;

usageAndExit if !@BUFiles;
@BUFiles = map { split /,/ } @BUFiles;

my %BUMaster = ();

foreach my $BUFile ( @BUFiles ) {
	parseBUFile ( $BUFile , \%subProdMap , \%BUMaster );
}

my %qtyMap = ();

local $| = 1;

print STDERR "Rec,Sym,Vol,Price,TrdCnt,ActID,ActBU,ActFee,ActRate,NewActFee,NewActRate,PsvID,PsvBU,PsvFee,PsvRate,NewPsvFee,NewPsvRate,FeeDiff\n";

while ( <> ) {
	my @rec = split /,/;
	my ( $sym , $vol , $price , $trdCnt ) = @rec[ 2 , 8 , 9 , 10 ];
	my @POs = @rec[ 4 , 6 ];
	my @trdrIDs = @rec[ 5 , 7 ];
	my @origFees = @rec[ 15 , 33 ];
	my @actPsvs = @rec[ 16 , 34 ];
	my @subProds = @rec[ 19 , 37 ];

#	Filter out uninteresting records.
#	---------------------------------	
	next if $POs[ 0 ] ne $POs[ 1 ];
	my $PO = $POs[ 0 ];
	
	next if !exists $BUMaster{ $PO };
	
	my @prods = ( $revSubProdMap{ $subProds[ 0 ] } , $revSubProdMap{ $subProds[ 1 ] } );
	next if ( !$prods[ 0 ] || !$prods[ 1 ] || $prods[ 0 ] ne $prods[ 1 ] );
	my $prod = @prods[ 0 ];
	
	my @BUs = ( $BUMaster{ $PO }{ RevBUMap }{ $trdrIDs[ 0 ] } , $BUMaster{ $PO }{ RevBUMap }{ $trdrIDs[ 1 ] } );
	next if ( !$BUs[ 0 ] || !$BUs[ 1 ] );
	
	my ( $actIdx , $psvIdx ) = ( $actPsvs[ 0 ] eq 'A' ? ( 0 , 1 ) : ( 1 , 0 ) );

	my $defRates = "BU";
	my $rates = $BUMaster{ $PO }{ FeeMap }{ $prod }{ $BUs[ $actIdx ] }{ $BUs[ $psvIdx ] };
	if ( !$rates ) {
		$rates = $BUMaster{ $PO }{ FeeMap }{ $prod }{ BaseFees };
		$defRates = "DEF";
	}
	next if !$rates;	# --- this would be a data error ---

	for my $idx ( $actIdx , $psvIdx ) {
		my $key = "$trdrIDs[ $idx ],$BUs[ $idx ]";
		$key .= ",$subProds[ $idx ]" if $useSubProduct;
		if ( $showBothTrdrIDs ) {
			$key .= "," . $trdrIDs[ 1 - $idx ] . "," . $BUs[ 1 - $idx ];
			$key .= ",$subProds[ 1 - $idx ]" if $useSubProduct;
		}
		
		my $isActive = ( $idx == $actIdx );
		$qtyMap{ $key }{ TotVol } += $vol;
		$qtyMap{ $key }{ PsvVol } += $vol if !$isActive;
		$qtyMap{ $key }{ TotTrds } += $trdCnt;
		$qtyMap{ $key }{ OrigActFee } += $origFees[ $idx ] if $isActive;
		$qtyMap{ $key }{ OrigPsvFee } += $origFees[ $idx ] if !$isActive;
		$qtyMap{ $key }{ ActFee } += $$rates[ 0 ] * $vol if $isActive;
		$qtyMap{ $key }{ PsvFee } += $$rates[ 1 ] * $vol if !$isActive;
	}
	
	my @origRates = ( $origFees[ 0 ] / $vol , $origFees[ 1 ] / $vol );
	my @newFees = ( $$rates[ 0 ] * $vol , $$rates[ 1 ] * $vol );
	my $feeDiff = $newFees[ 0 ] + $newFees[ 1 ] - ( $origFees[ 0 ] + $origFees[ 1 ] );
	
	printf STDERR "REC:%d,%s,%d,%.3f,%.1f,%s,%s,%.2f,%.4f,%.2f,%.3f,%s,%s,%.2f,%.4f,%.2f,%.4f,%.3f\n" , 
					$. , $sym , $vol , $price , $trdCnt , 
					$BUs[ $actIdx ] , $trdrIDs[ $actIdx ] , $origFees[ $actIdx ] , $origRates[ $actIdx ] , $newFees[ 0 ] , $$rates[ 0 ] ,
					$BUs[ $psvIdx ] , $trdrIDs[ $psvIdx ] , $origFees[ $psvIdx ] , $origRates[ $psvIdx ] , $newFees[ 1 ] , $$rates[ 1 ] ,
					$feeDiff;
	
}

print "TRDR_ID,BUS_UNIT," , 
		( $showBothTrdrIDs ? "CONTRA_TRDR_ID,CONTRA_BUS_UNIT," : "" ) ,
		( $useSubProduct ? "SUBPRODUCT," : "" ) ,
		"TOTAL_VOL,PASSIVE_VOL,TOTAL_TRDS,ORIG_ACT_FEE,ORIG_PSV_FEE,NEW_ACT_FEE,NEW_PSV_FEE,ORIG_NET_FEE,NEW_NET_FEE\n";
foreach my $key ( sort keys %qtyMap ) {
	printf "%s,%d,%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n" ,
			$key , 
			$qtyMap{ $key }{ TotVol } ,
			$qtyMap{ $key }{ PsvVol } ,
			$qtyMap{ $key }{ TotTrds } ,
			$qtyMap{ $key }{ OrigActFee } ,
			$qtyMap{ $key }{ OrigPsvFee } ,
			$qtyMap{ $key }{ ActFee } ,
			$qtyMap{ $key }{ PsvFee } ,
			$qtyMap{ $key }{ OrigActFee } + $qtyMap{ $key }{ OrigPsvFee } ,
			$qtyMap{ $key }{ ActFee } + $qtyMap{ $key }{ PsvFee }
}