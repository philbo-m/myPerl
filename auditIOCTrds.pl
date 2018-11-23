#!c:/perl/bin/perl

use strict;

use Data::Dumper;

use STAMP::STAMPStream;
use Quote;

my %quoteBySym;

my $recordSep = $/;
# my $recordSep = chr ( 001 );

my %trdMap = ();
my $date;

my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => 1 , RecordSep => $recordSep );

while ( my $msg = $stream->next ) {

#	Look only for IOC boardlot trades (non-SDL, if we ever run this on TSX/V).  Omit self trades.
#	--------------------------------------------------------------------------------------------- 	
	next if !( $msg->isa ( "STAMP::STAMPTradeMsg" ) );
	next if $msg->getAttr ( "SelfTrade" );
	my $iocIdx = -1;
	foreach my $idx ( 0 , 1 ) {
		if ( $msg->getAttr ( "OrderDuration" , $idx ) eq 'IOC' ) {
			$iocIdx = $idx;
			last;
		}
	}
	next if $iocIdx == -1;

	next if $msg->getAttr ( "SeekDarkLiquidity" , $iocIdx );
	next if ( $msg->getAttr ( "Market" , $iocIdx ) ne 'Boardlot' );
	
	my $sym = $msg->getAttr ( "Symbol" );
	my $vol = $msg->getAttr ( "Volume" );
	my $po = $msg->getAttr ( "BrokerNumber" , $iocIdx );
	my $clOrdID = $msg->getAttr ( "UserOrderId" , $iocIdx );
	my $remVol = $msg->getAttr ( "RemainingVolume" , $iocIdx );
	if ( !$date ) {
		( $date = $msg->date) =~ s/(....)(..)(..)/$2\/$3\/$1/;
	}

	if ( !exists $trdMap{ $sym }{ $po }{ $clOrdID } ) {
		$trdMap{ $sym }{ $po }{ $clOrdID }{ OrderVol } = $vol + $remVol;
	}
	$trdMap{ $sym }{ $po }{ $clOrdID }{ TradeVol } += $vol;
	$trdMap{ $sym }{ $po }{ $clOrdID }{ TradeCnt } ++;
}

foreach my $sym ( sort keys %trdMap ) {
	my ( $ordVol , $trdVol , $trdCnt );
	foreach my $po ( keys %{ $trdMap{ $sym } } ) {
		foreach my $clOrdID (  keys %{ $trdMap{ $sym }{ $po } } ) {
			$ordVol += $trdMap{ $sym }{ $po }{ $clOrdID }{ OrderVol };
			$trdVol += $trdMap{ $sym }{ $po }{ $clOrdID }{ TradeVol };
			$trdCnt += $trdMap{ $sym }{ $po }{ $clOrdID }{ TradeCnt };
		}
	}
	print "$sym,$date,$ordVol,$trdVol,$trdCnt\n";
}
