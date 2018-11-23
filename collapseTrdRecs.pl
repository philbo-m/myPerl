#!c:/perl/bin/perl

use strict;

# PO,TRADER ID,MARKET ID,SYMBOL,SUB-PRODUCT,VOLUME,VALUE,TOTAL TRADE LEGS,ACTIVE VOLUME,PASSIVE VOLUME,BASIC FEE,NET FEE

my @keyFldIdxs = ( 0 , 1 , 2 , 3 , 4 );
my $subPrdIdx = 4;
my @qtyFldIdxs = ( 5 , 6 , 7 , 8 , 9 , 10 , 11 );

my @prevRec;

while ( <> ) {
	chomp;
	s/"//g;
	
	my @rec = split /,/;
	$rec[ $subPrdIdx ] =~ s/_T[12]_REG$/_TX/;
	$rec[ $subPrdIdx ] =~ s/_T[12](_|$)/_TX$1/;
	
	if ( @prevRec ) {
		foreach my $idx ( @keyFldIdxs ) {
			if ( $rec[ $idx ] ne $prevRec[ $idx ] ) {

#				New record.  Spit out the previous rec.
#				---------------------------------------
				print join ( "," , @prevRec ) , "\n";
				@prevRec = ();
				last;
			}
		}
	}
	if ( @prevRec ) {
		print STDERR "Joining\n...[" , join ( "," , @prevRec ) , "]\n...[" , join ( "," , @rec ) , "]\n";
	}
	@prevRec[ @keyFldIdxs ] = @rec[ @keyFldIdxs ];
	foreach my $idx ( @qtyFldIdxs ) {
		$prevRec[ $idx ] += $rec[ $idx ];
	}
}

print join ( "," , @prevRec ) , "\n";