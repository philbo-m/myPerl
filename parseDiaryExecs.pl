#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

sub fldsToRec {
	my ( $recArray ) = @_;
	my @flds = map {
					if ( /[,"\n]/ ) {
						s/"/""/gs;
						s/(.*)/"$1"/s;
					}
					$_;
				} @$recArray;
				
	return join "," , @flds;
}

sub parseSide {
	my ( $sideInfo ) = @_;
	my ( $po , $trdrID , $trdrType , $acct , $jit ) = split ( /\s+/ , $sideInfo );
	if ( !$trdrID || $trdrID eq '(A)' ) {
		return ( $po , undef , undef , undef );
	}
	else {
		return ( $po , $trdrID , $trdrType , $acct , $jit );
	}
}
	
sub parseRec {
	my ( $rec , $po , $sym , $symDesc ) = @_;
	my ( $symInfo , $time , $vol , $price , $undisclBuyVol , $undisclSellVol , $buyInfo , $sellInfo ) = unpack ( "A35xA8xA12xA11xA12xA12xA38xA38" , $rec );
	my @symInfo = ( $symInfo =~ /^(.*?)\s+(.*?)\s*$/ );
	if ( $symInfo[ 0 ] ) {
		( $sym , $symDesc ) = @symInfo;
	}
	$vol =~ s/[\s,]//g;
	$price =~ s/\s//g;
	
	my ( $side , $poInfo , $contraInfo );
	my ( $trdrID , $trdrType , $acct , $jit , $contraPO );
	
	print STDERR "[$symInfo] [$time] [$vol] [$price] [$buyInfo] [$sellInfo]...\n";
	if ( $buyInfo =~ /^$po/ ) {
		$side = "B";
		$poInfo = $buyInfo;
		$contraInfo = $sellInfo;
		print STDERR "BUY SIDE FOR [$po] : [$poInfo] [$contraInfo]...\n";
	}
	else {
		$side = "S";
		$poInfo = $sellInfo;
		$contraInfo = $buyInfo;
		print STDERR "SELL SIDE FOR [$po] : [$poInfo] [$contraInfo]...\n";
	}
	
	( undef , $trdrID , $trdrType , $acct , $jit ) = parseSide ( $poInfo );
	( $contraPO , undef , undef , undef , undef ) = parseSide ( $contraInfo );
	
	return ( $sym , $symDesc , $time , $side , $vol , $price , $trdrID , $trdrType , $acct , $contraPO );
}

my ( $exch , $sym , $symDesc , $time , $po , $trdrID , $trdrType , $acct , $contraPO , $side , $vol , $price , $mrkrs );

print fldsToRec ( [ "Exchange" , "Symbol" , "Security" , "Time" , "PO" , "Trader ID" , "Trader Type" , "Account" , 
							"Contra PO" , "Side" , "Volume" , "Price" , "Markers" ] ) , "\n";

while ( <> ) {

#	Skip records we know we don't need.
#	-----------------------------------
	next if ( /^(SYMBOL|$)/ );
	next if ( /-- BUYER --/ );
	
#	Grab the exchange.
#	------------------
	if ( /^(QXA|Alpha)/ ) {
		chomp;
		( $exch =  $_ ) =~ s/^.*-//;
		next;
	}
		
#	Bail at end of file.
#	--------------------
	last if ( /MARKER LEGEND/ );
	
	chomp;
	if ( /^Broker-(\d+)/ ) {
		$po = $1;
	}
	elsif ( /MARKERS:\s*(.*?)\s*$/ ) {
		$mrkrs = $1;
		print fldsToRec ( [ $exch , $sym , $symDesc , $time , $po , $trdrID , $trdrType , $acct , $contraPO , $side , $vol , $price , $mrkrs ] ) , "\n";
	}
	
	else {
		( $sym , $symDesc , $time , $side , $vol , $price , $trdrID , $trdrType, $acct , $contraPO ) 
				= parseRec ( $_ , $po , $sym , $symDesc );
	}
	
}
