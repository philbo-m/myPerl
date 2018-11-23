#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use FIXFld;

my %revTagMap = map { $FIXFld::tagMap{ $_ } => $_ } %FIXFld::tagMap;

sub dateToStr {
	my ( $date ) = @_;
	my ( $mm , $dd , $yyyy ) = split ( /\// , $date );
	return "${yyyy}${mm}${dd}";
}

sub parseRec {
	my ( $rec ) = @_;
	
	my ( $sym , undef , $qty , $val , $venue , $bs , $date , $orderNum , $trdrID , $execTime ) = split ( /,/ , $rec );
	return if ( !$sym || $qty !~ /^\d+$/ );
	
	my $avgPx = sprintf ( "%.4f" , $val / $qty );
	my $side = ( $bs eq 'B' ? 1 : 2 );
	
	my $dateStr = dateToStr ( $date );
	my $orderID = sprintf ( "${bs}${dateStr}%09d" , $orderNum );
	
	my $xactTime = ( split / / , $execTime )[ 1 ];
	$xactTime = "${dateStr}-${xactTime}:00.000";
	
	
	my @fixFlds = ( 
		[ $revTagMap{ "Symbol" } , $sym ] ,
		[ $revTagMap{ "CumQty" } , $qty ] ,
		[ $revTagMap{ "AvgPx" } , $avgPx ] ,
		[ $revTagMap{ "Side" } , $side ] ,
#		[ $revTagMap{ "OrdStatus" } , 2 ] ,
#		[ $revTagMap{ "ExecType" } , 2 ] ,
		[ $revTagMap{ "OrderID" } , $orderID ] ,
		[ $revTagMap{ "LastShares" } , $qty ] ,
		[ $revTagMap{ "TransactTime" } , $xactTime ] ,
#		[ $revTagMap{ "LeavesQty" } , 0 ] ,
		[ $revTagMap{ "TSXUserID" } , $trdrID ]
	);

	my $delim = "";
#	$delim = "|";
	
	print join ( $delim , map { "$$_[ 0 ]=$$_[ 1 ]" } @fixFlds ) , "\n";
}
	
while ( <> ) {
	chomp;
	my ( $bRec , $sRec ) = split /,,/;
	foreach my $rec ( $bRec , $sRec ) {
		parseRec ( $rec );
	}
}	
	