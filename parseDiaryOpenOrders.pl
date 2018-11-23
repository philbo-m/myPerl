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
# SYMBOL         ORDER NO          TIME     CLIENT JITNEY BROKER OPRN       VOLUME       PRICE BALANCE      DUR      TERMS             SPECIAL
#     5    10   15   20   25   30   35   40   45   50   55   60   65   70   75   80   85   90   95   100  105  110  115  120  125  130  135  140  145  150  155  160
# ----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|
# -------------- ----------------- -------- ------ ------------- ---- ------------ ----------- ------------ -------- ----------------- -------------------- ---------------
# LYD            B20180402000001   08:15:11 CL                   B             500     0.20000          500 29/06                       BK                   EM LL

sub parseRec {
	my ( $rec ) = @_;
	
#	--- Pad out to max line len so unpack doesn't break ---
	my $maxLen = 169;
	my $pad = $maxLen - length ( $rec );
	$rec .= ' ' x $pad if $pad;
	
	my ( $sym , $orderID , $time , $acctType , $jit , $side , $vol , $price , $balance , $duration , $terms , $special , $markers )                       
		= unpack ( "A14xA17xA8xA6xA13xA4xA12xA11xA12xA8xA17xA20xA15" , $rec );

	$sym =~ s/\s//g;
	$vol =~ s/[\s,]//g;
	$balance =~ s/[\s,]//g;
	$price =~ s/\s//g;
		
	return ( $sym , $orderID , $time , $acctType , $jit , $side , $vol , $price , $balance , $duration , $terms , $special , $markers );
}

print fldsToRec ( [ "Exchange" , "Symbol" , "PO" , "TraderID" , "Jitney PO" , "Acct Type" , "OrderID" , "Time" ,
					"Side" , "Volume" , "Price" , "Balance" , "Duration" , "Terms" , "Special" , "Markers" ] ) , "\n";

my ( $exch , $sym , $po , $trdrID , $orderID , $time , $acctType , $jit , $side , $vol , $price , $balance , $duration , $terms , $special , $markers );
my $prevSym;

while ( <> ) {

#	Skip records we know we don't need.
#	-----------------------------------
	next if ( /^(SYMBOL|----|$)/ );
	
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
	if ( /^Broker (\d+) User (\S+)/ ) {
		$po = $1;
		$trdrID = $2;
	}
	else {
		( $sym , $orderID , $time , $acctType , $jit , $side , $vol , $price , $balance , $duration , $terms , $special , $markers ) = parseRec ( $_ );
		if ( $sym ) {
			$prevSym = $sym;
		}
		else {
			$sym = $prevSym;
		}
		print fldsToRec ( [ $exch , $sym , $po , $trdrID , $jit , $acctType , $orderID , $time , $side , $vol , $price , $balance , $duration , $terms , $special , $markers ] ) , "\n";
	}
}
