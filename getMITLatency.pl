#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use FIXMsg;
use Util;

use File::Basename;
use lib dirname $0;

sub nextOrderID {
	my ( $orderID ) = @_;
	my @idArr = ( split '' , $orderID );
	
	for ( my $i = $#idArr ; $i >= $#idArr - 2 ; $i-- ) {
		$idArr[ $i ] = nextDigit ( $idArr[ $i ] );
		last if $idArr[ $i ] ne '0';
	}
	
	return join ( '' , @idArr );
}

sub nextDigit {
	my ( $digit ) = @_;
	
	my @digits = ( 0..9 , 'A'..'Z' , 'a'..'z' );
	my $idx = 0;
	my %digits = map { $_ => $idx++ } @digits;
	
	return $digits[ ( $digits{ $digit } + 1 ) % ( $#digits + 1 ) ];
}

my $clientFile;

GetOptions ( 
	'c=s'	=> \$clientFile
) or die;

die if !$clientFile;

my %tsMap = ();

my %exDestMap = ( 
		ALE		=> "XATS" ,
		CDX		=> "" ,
		TSX		=> ""
	);
	
open CF , $clientFile;
while ( <CF> ) {
	chomp;
	my ( $ts , $trdrID , $sym , $side , $qty , $price , $clOrdID , $orderID , $exDest ) = split /,/;

	$orderID = nextOrderID ( $orderID );
	
	$tsMap{ "$trdrID,$sym,$side,$orderID" } = $ts;
	
}
close CF;

# STDIN should be MIT market-side New Orders (35=D) only.
# -------------------------------------------------------
while ( <> ) {
	chomp;
	my $msg = new FIXMsg ();
	$msg->parse ( $_ );
	
	my $trdrID = $msg->fldVal ( "TSXUserID" );
	my $sym = $msg->fldVal ( "Symbol" );
	my $side = $msg->fldVal ( "Side" );
	my $qty = $msg->fldVal ( "OrderQty" );
	my $price = $msg->fldVal ( "Price" );
	my $clOrdID = $msg->fldVal ( "ClOrdID" );
	
	my $clTS = delete $tsMap { "$trdrID,$sym,$side,$clOrdID" };
	if ( $clTS ) {
		my $ts = $msg->fldVal ( "TimeStamp" );
		print "$clTS,$ts," , Util::tsDiff ( $clTS , $ts ) , "\n";
	}
}

		
	
	

