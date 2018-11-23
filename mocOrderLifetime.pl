#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use STAMPOrder;

my %exchMap = (
	TSE		=> "TSX" ,
	CDX		=> "TSXV"
);

sub timeDiff {
	my ( $t1 , $t2 ) = @_;	# --- YYYYMMDDhhmmssmm
	my $diff = ( ( $t2 % 10000 ) - ( $t1 % 10000 ) ) * 10;	# --- seconds and milliseconds ---
	$t1 = int ( $t1 / 10000 ) ; $t2 = int ( $t2 / 10000 );
	$diff += ( ( $t2 % 100 ) - ( $t1 % 100 ) ) * 60000;	# --- minutes ---
	$t1 = int ( $t1 / 100 ) ; $t2 = int ( $t2 / 100 );
	$diff += ( ( $t2 % 100 ) - ( $t1 % 100 ) ) * 3600000;	# --- hours ---
	
	return $diff;
}

sub otherSide {
	my ( $side ) = @_;
	return ( $side eq 'Buy' ? 'Sell' : 'Buy' );
}

sub printOrder {
	my ( $order , $event , $ts , $po , $sym , $orderNo , $diff ) = @_;
	
	print "$order->{timeStamp},$ts,$po,$order->{trdrID},$sym,$order->{exchange},$orderNo,$order->{side},$order->{volume},$order->{remVol},$order->{price},$order->{refPrice},$event,$diff\n";
}

sub dbg {
#	print STDERR @_;
}

sub mkFldIdxs {
	my ( $rec ) = @_;
	
	my $idx = 0;
	my %fldIdxs = map { $_ => $idx++ } split ( /,/ , $rec );
	return \%fldIdxs;
}

sub parseImbalances {
	my ( $imbalFile , $symMap ) = @_;
	
	open FILE , $imbalFile or die $!;
	my $hdr = <FILE>;
	chomp $hdr;
	my $fldIdxs = mkFldIdxs ( $hdr );
	my $symIdx = $$fldIdxs{ "Symbol" };
	
	while ( <FILE> ) {
		chomp;
		my @rec = split /,/;
		my $sym = $rec[ $$fldIdxs{ "Symbol" } ];
		foreach my $fld ( keys %$fldIdxs ) {
			next if $fld eq 'Symbol';
			$$symMap{ $sym }{ $fld } = $rec[ $$fldIdxs{ $fld } ];
		}
	}
	close FILE;
}
			
sub parseOrders {
	my ( $orderFile , $orderMap , $symMap ) = @_;
	
	my ( $cxlTS , $cxlPO , $cxlSym , $cxlOrderNo );
	my $pendingCxl;
	
	open FILE , $orderFile or die $!;
	my $hdr = <FILE>;
	chomp $hdr;
	my $fldIdxs = mkFldIdxs ( $hdr );
	
	while ( <FILE> ) {
		chomp;
		dbg "[$_]\n";

		my @rec = split /,/;
		my $ts = $rec[ $$fldIdxs{ "TimeStamp" } ];
		my $busClass = $rec[ $$fldIdxs{ "BusinessClass" } ];
		my $confType = $rec[ $$fldIdxs{ "ConfirmationType" } ];
		my $trdrID = $rec[ $$fldIdxs{ "UserId" } ];
		my $po = $rec[ $$fldIdxs{ "BrokerNumber" } ];
		my $pvtPO = $rec[ $$fldIdxs{ "PrivateBrokerNumber" } ];
		my $sym = $rec[ $$fldIdxs{ "Symbol" } ];
		my $exch = $rec[ $$fldIdxs{ "ExchangeId" } ];
		my $side = $rec[ $$fldIdxs{ "BusinessAction" } ];
		my $vol = $rec[ $$fldIdxs{ "Volume" } ];
		my $prc = $rec[ $$fldIdxs{ "Price" } ];
		my $orderNo = $rec[ $$fldIdxs{ "OrderNumber" } ];
		my $cfodOrderNo = $rec[ $$fldIdxs{ "CFOdOrderNumber" } ];
		my $newOrderNo = $rec[ $$fldIdxs{ "NewOrderNumber" } ];
		
		$exch = $exchMap{ $exch };
		if ( $pvtPO ) {
			$po = $pvtPO;
		}
		
#		Deal with cancel/rebook first.
#		------------------------------
		if ( $pendingCxl ) {
			$pendingCxl = undef;
			my $cxlType;

#			Treat CFOs as CXLs and the rebooks as brand new orders.
#			Just record which type of CXL it was in the prev record - 1st half of a CFO or straight CXL.
#			--------------------------------------------------------------------------------------------
			if ( $busClass eq 'OrderCancelResp' && $confType eq 'Booked'
					&& $cxlPO eq $po && $cxlSym eq $sym && $cxlOrderNo eq $cfodOrderNo ) {
				$cxlType = "CXL-CFO";
			}
			else {
				$cxlType = "CXL";
			}
			cxlOrder ( $orderMap , $cxlTS , $cxlPO , $cxlSym , $cxlOrderNo , $cxlType );
		}
		
		if ( $busClass eq 'OrderCancelResp' ) {
			if ( $confType eq 'Booked' ) {

#				Brand new order.
#				----------------
				addOrder ( $orderMap , $symMap , $ts , $po , $trdrID , $sym , $exch , $side , $vol , $prc , $orderNo );
			}	
			elsif ( $confType eq 'Cancelled' ) {
		
#				Save the CXL info in case it's the first half of a CXL/Rebook.
#				--------------------------------------------------------------
				dbg "[$ts] Saving CXL [$po,$sym,$orderNo]\n";
				$pendingCxl = 1;
				( $cxlTS , $cxlPO , $cxlSym , $cxlOrderNo ) = ( $ts , $po , $sym , $orderNo );
			}
		}
		elsif ( $busClass eq 'CFO-Resp' && $confType eq 'Accepted' ) {
	
#			Straightforward CFO (iceberg order refreshing itself?)
#			------------------------------------------------------
			cfoOrder ( $orderMap , $ts , $po , $sym , $cfodOrderNo , $newOrderNo );
		}
	}
	close FILE;
}

sub parseTrades {
	my ( $trdFile , $orderMap , $symMap ) = @_;

	open FILE , $trdFile or die $!;
	my $hdr = <FILE>;
	chomp $hdr;
	my $fldIdxs = mkFldIdxs ( $hdr );
	
	while ( <FILE> ) {
		chomp;
		dbg "[$_]\n";
		
		my @rec = split /,/;
		my $ts = $rec[ $$fldIdxs{ "TimeStamp" } ];
		my $busClass = $rec[ $$fldIdxs{ "BusinessClass" } ];
		my $busAct = $rec[ $$fldIdxs{ "BusinessAction" } ];
		my $sym = $rec[ $$fldIdxs{ "Symbol" } ];
		my $vol = $rec[ $$fldIdxs{ "Volume" } ];
		my $price = $rec[ $$fldIdxs{ "Price" } ];
		my $po0 = $rec[ $$fldIdxs{ "BrokerNumber" } ];
		my $pvtPO0 = $rec[ $$fldIdxs{ "PrivateBrokerNumber" } ];
		my $trdrId0 = $rec[ $$fldIdxs{ "UserId" } ];
		my $orderNo0 = $rec[ $$fldIdxs{ "OrderNumber" } ];
		my $cfodOrderNo0 = $rec[ $$fldIdxs{ "CFOdOrderNumber" } ];
		my $exchAdmin0 = $rec[ $$fldIdxs{ "Exchange-Admin" } ];
		my $remVol0 = $rec[ $$fldIdxs{ "RemainingVolume" } ];
		my $po1 = $rec[ $$fldIdxs{ "BrokerNumber.1" } ];
		my $pvtPO1 = $rec[ $$fldIdxs{ "PrivateBrokerNumber.1" } ];
		my $trdrId1 = $rec[ $$fldIdxs{ "UserId.1" } ];
		my $orderNo1 = $rec[ $$fldIdxs{ "OrderNumber.1" } ];
		my $cfodOrderNo1 = $rec[ $$fldIdxs{ "CFOdOrderNumber.1" } ];
		my $exchAdmin1 = $rec[ $$fldIdxs{ "Exchange-Admin.1" } ];
		my $remVol1 = $rec[ $$fldIdxs{ "RemainingVolume.1" } ];
		
		my $exch = ( $exchAdmin0 =~ /^T/ ? 'TSX' : 'TSXV' );

		if ( $pvtPO0 ) {
			$po0 = $pvtPO0;
		}
		if ( $pvtPO1 ) {
			$po1 = $pvtPO1;
		}
		
		my $order0 = $$orderMap{ $po0 }{ $sym }{ $orderNo0 };
		my $order1 = $$orderMap{ $po1 }{ $sym }{ $orderNo1 };
		if ( !$order0 && $order1 && ( $order1->{volume} % 100 ) && $remVol1 == 0 ) {
			my $otherSide = otherSide ( $order1->{side} );
			print STDERR "Adding odd-lot order [$po0] [$trdrId0] [$orderNo0] [$otherSide] [$vol] [$sym] [$price]\n";
			$order0 = addOrder ( $orderMap , $symMap , $ts , $po0 , $trdrId0 , $sym , $order1->{exchange} , $otherSide ,
									$vol , $price , $orderNo0 );
		}
		elsif ( !$order1 && $order0 && ( $order0->{volume} % 100 ) && $remVol0 == 0 ) {
			my $otherSide = otherSide ( $order0->{side} );
			print STDERR "Adding odd-lot order [$po1] [$trdrId1] [$orderNo1] [$otherSide] [$vol] [$sym] [$price]\n";
			$order1 = addOrder ( $orderMap , $symMap , $ts , $po1 , $trdrId1 , $sym , $order0->{exchange} , $otherSide ,
									$vol , $price , $orderNo1 );
		}

		applyTrade ( $orderMap , $ts , $po0 , $sym , $orderNo0 , $remVol0 );
		applyTrade ( $orderMap , $ts , $po1 , $sym , $orderNo1 , $remVol1 );
	}

	close FILE;
}

sub addOrder {
	my ( $orderMap , $symMap , $ts , $po , $trdrID , $sym , $exch , $side , $vol , $prc , $orderNo ) = @_;
	my $order = new STAMPOrder ( timeStamp => $ts , side => $side , volume => $vol , price => $prc , 
									exchange => $exch , trdrID => $trdrID , refPrice => $$symMap{ $sym }{ "ImbalanceReferencePrice" } );
	$$orderMap{ $po }{ $sym }{ $orderNo } = $order;
	
	dbg "[$ts] New order [$po,$trdrID,$sym,$vol,$orderNo,$prc,$$symMap{ $sym }{ 'ImbalanceReferencePrice' }]\n";
}

sub cxlOrder {
	my ( $orderMap , $ts , $po , $sym , $orderNo , $cxlType ) = @_;
	my $order = delete $$orderMap{ $po }{ $sym }{ $orderNo };
	if ( !$order ) {
		print STDERR "[$ts] CXLed order [$po,$sym,$orderNo] : original order not found.\n";
		return;
	}
	
	my $orderTime = $order->{timeStamp};
	dbg "[$ts] ${cxlType}ed order [$po,$sym,$orderNo] order time [$orderTime]\n";
	my $diff = timeDiff ( $orderTime , $ts );
	printOrder ( $order , $cxlType , $ts , $po , $sym , $orderNo , $diff );
}
	
sub cfoOrder {
	my ( $orderMap , $ts , $po , $sym , $vol , $origOrderNo , $orderNo ) = @_;
	my $order = delete $$orderMap{ $po }{ $sym }{ $origOrderNo };
	if ( !$order ) {
		print STDERR "[$ts] CFOed order [$po,$sym,$origOrderNo]->[$po,$sym,$orderNo] : original order not found.\n";
		return;
	}
	dbg "[$ts] CFO order [$po,$sym,$origOrderNo]->[$po,$sym,$orderNo]\n";
	
	$$orderMap{ $po }{ $sym }{ $orderNo } = $order;
	$order->{cfoCount}++;
	$order->{volume} = $vol;
}

sub applyTrade {
	my ( $orderMap , $ts , $po , $sym , $orderNo , $remVol ) = @_;
	my $order = $$orderMap{ $po }{ $sym }{ $orderNo };
	if ( !$order ) {
#		print STDERR "[$ts] Executed order [$po,$sym,$orderNo] : original order not found.\n";
		return;
	}
	
	my $orderTime = $order->{timeStamp};
	dbg "[$ts] Executed order [$po,$sym,$orderNo] order time [$orderTime]\n";
	my $diff = timeDiff ( $orderTime , $ts );
	$order->{remVol} = $remVol;
	
	if ( $remVol == 0 ) {
		printOrder ( $order , "EXEC" , $ts , $po , $sym , $orderNo , $diff );
		delete $$orderMap{ $po }{ $sym }{ $orderNo };
	}
}

my %symMap = ();
my %orderMap = ();

my ( $imbalFiles , $orderFiles , $tradeFiles ) = @ARGV;

foreach my $imbalFile ( split /,/ , $imbalFiles ) {
	parseImbalances ( $imbalFile , \%symMap );
}
foreach my $orderFile ( split /,/ , $orderFiles ) {
	parseOrders ( $orderFile , \%orderMap , \%symMap );
}
foreach my $tradeFile ( split /,/ , $tradeFiles ) {
	parseTrades ( $tradeFile , \%orderMap , \%symMap );
}

foreach my $po ( keys %orderMap ) {
	foreach my $sym ( keys %{ $orderMap{ $po } } ) {
		foreach my $orderNo ( keys %{ $orderMap{ $po }{ $sym } } ) {
			my $order = $orderMap{ $po }{ $sym }{ $orderNo };
			printOrder ( $order , "OPEN" , "" , $po , $sym , $orderNo , "" );
		}
	}
}
