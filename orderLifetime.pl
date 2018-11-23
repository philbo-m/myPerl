#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use STAMPOrder;

my %exchMap = (
	TSE		=> "TSX" ,
	CDX		=> "TSXV"
);

# Returns the time difference between t1 and t2 in nanoseconds.
# =============================================================
sub timeDiff {
	my ( $t1 , $t2 ) = @_;	# --- YYYYMMDDhhmmssmm or YYYYMMDDhhmmssnnnnnnnnn
	my ( $h1 , $m1 , $s1 ) = ( $t1 =~ /^\d{8}(\d{2})(\d{2})(\d+)$/ );
	my ( $h2 , $m2 , $s2 ) = ( $t2 =~ /^\d{8}(\d{2})(\d{2})(\d+)$/ );
	$s1 =~ s/^(\d{2})(\d+)/$1.$2/;
	$s2 =~ s/^(\d{2})(\d+)/$1.$2/;
	
	my $diff = ( $h2 - $h1 ) * 3600
				+ ( $m2 - $m1 ) * 60
				+ ( $s2 - $s1 );
	return sprintf ( "%.0f" , $diff * 1000000000 );
}

sub printOrder {
	my ( $order , $event , $ts , $po , $sym , $orderNo , $diff ) = @_;
	
	print "$order->{timeStamp},$ts,$po,$order->{trdrID},$sym,$order->{exchange},$orderNo,$order->{volume},$order->{cfoCount},$event,$diff\n";
}

sub dbg {
#	print STDERR @_;
}

sub parseOrders {
	my ( $orderFile , $orderMap ) = @_;
	
	my ( $cxlTS , $cxlPO , $cxlSym , $cxlOrderNo );
	my $pendingCxl;
	
	open FILE , $orderFile or die $!;
	my $hdr = <FILE>;
	chomp $hdr;
	my $idx = 0;
	my %fldIdxs = map { $_ => $idx++ } split ( /,/ , $hdr );
	
	while ( <FILE> ) {
		chomp;
		dbg "[$_]\n";

		my @rec = split /,/;
		my $ts = $rec[ $fldIdxs{ "TimeStamp" } ];
		my $busClass = $rec[ $fldIdxs{ "BusinessClass" } ];
		my $confType = $rec[ $fldIdxs{ "ConfirmationType" } ];
		my $trdrID = $rec[ $fldIdxs{ "UserId" } ];
		my $po = $rec[ $fldIdxs{ "BrokerNumber" } ];
		my $sym = $rec[ $fldIdxs{ "Symbol" } ];
		my $exch = $rec[ $fldIdxs{ "ExchangeId" } ];
		my $vol = $rec[ $fldIdxs{ "Volume" } ];
		my $orderNo = $rec[ $fldIdxs{ "OrderNumber" } ];
		my $cfodOrderNo = $rec[ $fldIdxs{ "CFOdOrderNumber" } ];
		my $newOrderNo = $rec[ $fldIdxs{ "NewOrderNumber" } ];
		
		$exch = $exchMap{ $exch };
		
#		Deal with cancel/rebook first.
#		------------------------------
		if ( $pendingCxl ) {
			$pendingCxl = undef;
			my $cxlType;

#			10 Mar 2015 : Treat CFOs as CXLs and the rebooks as brand new orders.
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
				addOrder ( $orderMap , $ts , $po , $trdrID , $sym , $exch , $vol , $orderNo );
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
	my ( $trdFile , $orderMap ) = @_;

	open FILE , $trdFile or die $!;
	my $hdr = <FILE>;
	chomp $hdr;
	my $idx = 0;
	my %fldIdxs = map { $_ => $idx++ } split ( /,/ , $hdr );
	
	while ( <FILE> ) {
		chomp;
		dbg "[$_]\n";
		
		my @rec = split /,/;
		my $ts = $rec[ $fldIdxs{ "TimeStamp" } ];
		my $busClass = $rec[ $fldIdxs{ "BusinessClass" } ];
		my $busAct = $rec[ $fldIdxs{ "BusinessAction" } ];
		my $sym = $rec[ $fldIdxs{ "Symbol" } ];
		my $vol = $rec[ $fldIdxs{ "Volume" } ];
		my $po0 = $rec[ $fldIdxs{ "BrokerNumber" } ];
		my $orderNo0 = $rec[ $fldIdxs{ "OrderNumber" } ];
		my $cfodOrderNo0 = $rec[ $fldIdxs{ "CFOdOrderNumber" } ];
		my $exchAdmin0 = $rec[ $fldIdxs{ "Exchange-Admin" } ];
		my $remVol0 = $rec[ $fldIdxs{ "RemainingVolume" } ];
		my $po1 = $rec[ $fldIdxs{ "BrokerNumber.1" } ];
		my $orderNo1 = $rec[ $fldIdxs{ "OrderNumber.1" } ];
		my $cfodOrderNo1 = $rec[ $fldIdxs{ "CFOdOrderNumber.1" } ];
		my $exchAdmin1 = $rec[ $fldIdxs{ "Exchange-Admin.1" } ];
		my $remVol1 = $rec[ $fldIdxs{ "RemainingVolume.1" } ];
		
		my $exch = ( $exchAdmin0 =~ /^T/ ? 'TSX' : 'TSXV' );
		
		if ( $exchAdmin0 =~ /^.P/ && $remVol0 == 0 ) {
			applyTrade ( $orderMap , $ts , $po0 , $sym , $orderNo0 );
		}
		elsif ( $exchAdmin1 =~ /^.P/ && $remVol1 == 0 ) {
			applyTrade ( $orderMap , $ts , $po1 , $sym , $orderNo1 );
		}
	}
	close FILE;
}

sub addOrder {
	my ( $orderMap , $ts , $po , $trdrID , $sym , $exch , $vol , $orderNo ) = @_;
	my $order = new STAMPOrder ( timeStamp => $ts , volume => $vol , exchange => $exch , trdrID => $trdrID );
	$$orderMap{ $po }{ $sym }{ $orderNo } = $order;
	
	dbg "[$ts] New order [$po,$trdrID,$sym,$vol,$orderNo]\n";
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
	my ( $orderMap , $ts , $po , $sym , $orderNo ) = @_;
	my $order = delete $$orderMap{ $po }{ $sym }{ $orderNo };
	if ( !$order ) {
		print STDERR "[$ts] Executed order [$po,$sym,$orderNo] : original order not found.\n";
		return;
	}
	
	my $orderTime = $order->{timeStamp};
	dbg "[$ts] Executed order [$po,$sym,$orderNo] order time [$orderTime]\n";
	my $diff = timeDiff ( $orderTime , $ts );
	printOrder ( $order , "EXEC" , $ts , $po , $sym , $orderNo , $diff );
}

my %orderMap = ();

my ( $orderFiles , $tradeFiles ) = ( $ARGV[ 0 ] , $ARGV[ 1 ] );

foreach my $orderFile ( split /,/ , $orderFiles ) {
	parseOrders ( $orderFile , \%orderMap );
}
foreach my $tradeFile ( split /,/ , $tradeFiles ) {
	parseTrades ( $tradeFile , \%orderMap );
}