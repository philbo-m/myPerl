#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use FIXFld;

my %revTagMap = map { $FIXFld::tagMap{ $_ } => $_ } %FIXFld::tagMap;

my %exDestMap = (
	'A'		=> 'ALE' ,
	'S'		=> 'TMXS' ,
	'T'		=> 'TSX' ,
	'X'		=> 'CDX'
);

sub dateToStr {
	my ( $date ) = @_;
	my ( $mm , $dd , $yyyy ) = split ( /\// , $date );
	return "${yyyy}${mm}${dd}";
}

sub parseRec {
	my ( $rec ) = @_;
	
	my ( $sym , $qty , $price , $venue , $buyBrkr , $sellBrkr , $trdNo , $bs , $date , $orderNum , $trdrID , $execTime , $exchAdmin , $shortMrkr ) 
			= split ( /,/ , $rec );

	return if ( !$sym || $qty !~ /^\d+$/ );
	
	$price = sprintf ( "%.5f" , $price );
	my $side = ( $bs eq 'B' ? 1 : ( $shortMrkr eq 'N' ? 2 : 5 ) );
	
	my $dateStr = dateToStr ( $date );
	my $orderID = sprintf ( "${bs}${dateStr}%09d" , $orderNum );
	
	my ( $execDate , $execTime ) = ( split / / , $execTime )[ 1 ];
	$execDate = dateToStr ( $execDate );
	$execTime = "${execDate}-${execTime}:00.000";
	
	$exchAdmin =~ s/\s//g;
	my $exDest = $exDestMap{ substr ( $exchAdmin , 0 , 1 ) };
	
	
	my @fixFlds = ( 
		[ $revTagMap{ "MsgType" }			, 8 ] , 		# --- Execution Report ---
		[ $revTagMap{ "OrderID" } 			, $orderID ] ,
		[ $revTagMap{ "Symbol" } 			, $sym ] ,
		[ $revTagMap{ "ExecTransType" } 	, 0 ] ,			# --- New ---
		[ $revTagMap{ "CumQty" } 			, $qty ] ,
		[ $revTagMap{ "LastPx" } 			, $price ] ,
		[ $revTagMap{ "Side" } 				, $side ] ,
#		[ $revTagMap{ "OrdStatus" } 		, 2 ] ,			# --- Filled ---
#		[ $revTagMap{ "ExecType" } 			, 2 ] ,			# --- Fill ---
		[ $revTagMap{ "LastShares" } 		, $qty ] ,
		[ $revTagMap{ "TransactTime" } 		, $execTime ] ,
#		[ $revTagMap{ "LeavesQty" } 		, 0 ] ,
		[ $revTagMap{ "TSXUserID" } 		, $trdrID ] ,
		[ $revTagMap{ "TSXExchangeAdmin"  }	, $exchAdmin ] ,
		[ $revTagMap{ "ExDestination" }		, $exDest ]
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
	