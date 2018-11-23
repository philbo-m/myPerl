#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use STAMP::STAMPStream;
use STAMP::STAMPMsg;
use SymbolBook;
use StampFld;
use Quote;

sub applySTAMPTrade {
	my ( $symBook , $STAMPTradeMsg ) = @_;
	
	my %sideMap = ( 0 => 'Buy' , 1 => 'Sell' );
		my $price = $STAMPTradeMsg->getAttr ( "Price" );
		my $qty = $STAMPTradeMsg->getAttr ( "Volume" );
	
	foreach my $idx ( 0 , 1 ) {
		my $side = $sideMap{ $idx };
		
		my $po = $STAMPTradeMsg->getAttr ( "BrokerNumber.${idx}" );
		my $ClOrdID = $STAMPTradeMsg->getAttr ( "UserOrderId.${idx}" );
		my $remQty = $STAMPTradeMsg->getAttr ( "RemainingVolume.${idx}" );

		print STDERR "[" , $STAMPTradeMsg->timeStamp , "] : applying trade [$side] [$po] [$ClOrdID] [$qty] [$remQty] [$price]...\n";
		$symBook->applyTrade ( $po , $ClOrdID , $qty , $remQty , $price );
	}

	print STDERR "BOOK NOW :\n" , $symBook->dump , "\n\n";
}

sub apply STAMPQuote {
	my ( $symBook , $STAMPQuoteMsg ) = @_;

	$symBook->addQuote ( $STAMPQuoteMsg->getAttr ( "BidPrice" ) , $STAMPQuoteMsg->getAttr ( "AskPrice" ) , 
						$STAMPMsg->getAttr ( "STAMPQuoteMsg" ) , $STAMPQuoteMsg->getAttr ( "AskSize" ) ,
						$STAMPMsg->isLocal
					);
	print STDERR "[" , $STAMPQuoteMsg->timeStamp , "] : [" , $STAMPQuoteMsg->isLocal ? "INT" : "EXT" , "] QUOTE [" , $STAMPQuoteMsg->{BBO}->dump , "]...\n";
	$symBook->auditQuote;
}
	
sub applySTAMPMsg {
	my ( $symBook , $STAMPMsg ) = @_;
	
	if ( $STAMPMsg->isa ( "STAMP::STAMPSymStatusMsg" ) ) {
		$symBook->{BoardLotSize} = $STAMPMsg->getAttr ( "BoardLot" );
	}
	
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPOrderMsg" ) ) {
		my $order = $STAMPMsg->mkOrder;
		print STDERR "[" , $STAMPMsg->timeStamp , "] : [" , $order->dump , "]...\n";

		if ( $STAMPMsg->isMOC ) {
			return;
		}
		elsif ( $STAMPMsg->isCFO ) {
			$symBook->cfoOrder ( $order );
		}
		elsif ( $STAMPMsg->isKilled ) {
			$symBook->killOrder ( $order );
		}
		elsif ( $STAMPMsg->isCXL ) {
			$symBook->cxlOrder ( $order );
		}
		else {
			$symBook->addOrder ( $order , $STAMPMsg->isTriggeredOnStop );
		}
		print STDERR "BOOK NOW :\n" , $symBook->dump , "\n\n";
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPTradeMsg" ) ) {
		applySTAMPTrade ( $symBook , $STAMPMsg );
	}
	elsif ( $STAMPMsg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
		apply STAMPQuote ( $symBook , $STAMPMsg );
	}		
}
		
my %masterBook = ();

my $stream = new STAMP::STAMPStream ( file => "$ARGV[ 0 ]" );

while ( my $msg = $stream->next ) {

	my $sym = $msg->getAttr ( "Symbol" );
	my $symBook = $masterBook{ $sym };
	if ( !$symBook ) {
		$symBook = new SymbolBook ( Sym => $sym );
		$masterBook{ $sym } = $symBook;
	}
	
	applySTAMPMsg ( $symBook , $msg );
}