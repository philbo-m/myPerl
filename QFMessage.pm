package QFMessage;

use strict;

my %msgTypeMap = (
	
	0x30 => "Heartbeat" ,
	0x31 => "Login Request" ,
	0x32 => "Login Response" ,
	0x33 => "Logout message" ,
	0x34 => "Ack message" ,
	0x35 => "Replay Request" ,
	0x36 => "Sequence Jump" ,
	0x37 => "Reserved" ,
	0x38 => "Operation message" ,
	0x39 => "Reject" ,
	0	=> {
			Name	=> "Heartbeat" ,
			Type	=> "Admin" ,
			Parser	=> *parseHeartbeat
		},
	A	=> {
			Name	=> "Assign COP" ,
			Type	=> "Business" ,
			Parser	=> *parseAssignCOP
		} ,
	B	=> {
			Name	=> "Assign COP - No Orders" ,
			Type	=> "Business" ,
			Parser	=> *parseAssignCOPNoOrders
		} ,
	C	=> {
			Name	=> "Assign Limit" ,
			Type	=> "Business" ,
			Parser	=> *parseAssignLimit
		} ,
	E	=> {
			Name	=> "Market State Update" ,
			Type	=> "Business" ,
			Parser	=> *parseMktStateUpdate
		} ,
	I	=> {
			Name	=> "Stock Status" ,
			Type	=> "Business" ,
			Parser	=> *parseStockStatus
		} ,
	P	=> {
			Name	=> "Order Booked" ,
			Type	=> "Business" ,
			Parser	=> *parseOrderBooked
		} ,
	Q	=> {
			Name	=> "Order Cancelled" ,
			Type	=> "Business" ,
			Parser	=> *parseOrderCxled
		} ,
	S	=> {
			Name	=> "Trade Report" ,
			Type	=> "Business" ,
			Parser	=> *parseTradeRpt
		} ,
	T	=> {
			Name	=> "Trade Cancelled" ,
			Type 	=> "Business" , 
			Parser	=> *parseTradeCxled
		} ,
	U	=> {
			Name	=> "Trade Correction" ,
			Type 	=> "Business" ,
			Parser	=> *parseTradeCorr
		}
);

sub parse8byteBinary {
	my ( $binary ) = @_;
	my ( $low , $high ) = unpack ( "ll" , $binary );
	return ( $high * 2**32 ) + $low;
}

sub parseTS {
	my ( $ts ) = @_;
	my $tsVal = parse8byteBinary ( $ts );
	my $tsSec = int ( $tsVal / 1000000 );
	my $tsUsec = $tsVal % 1000000;
	
	my ( $sec , $min , $hr ) = ( gmtime ( $tsSec ) )[ 0 , 1 , 2 ];
	
	return sprintf ( "%02d:%02d:%02d:%06d" , $hr , $min , $sec , $tsUsec );
}

sub parsePrice {
	my ( $price ) = @_;
	return parse8byteBinary ( $price ) / 1000000;
}

sub parseHeartbeat {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Heartbeat\n";
	my ( $hdr , $remMsg ) = unpack ( "a6a*" , $msg );
	$msg = $remMsg;
	my $hbInt = unpack ( "x4v" , $hdr );
	for ( 0 .. $repeat ) {
		my ( $srcID , $streamID , $seq0 , $seq1 , $remMsg ) = unpack ( "avala*" , $msg );
		printf STDERR "HBInt [%d] Src [%d] Stream [%d] Seq 0 [%d] Seq 1 [%d]\n" ,
						$hbInt , ord ( $srcID ) , $streamID , ord ( $seq0 ) , $seq1;
		$msg = $remMsg;
	}
}

sub parseOrderCxled {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Order Cxled\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $po , $side , $orderID , $ts , $remMsg ) = unpack ( "a12a9vaa8a8a*" , $msg );
		printf STDERR "Sym [%s] PO [%03d] Side [%s] ID [%.0f] TS [%s]\n" ,
						$sym , $po , $side , 
						parse8byteBinary ( $orderID ) , 
						parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseOrderBooked {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Order Booked\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $po , $side , $orderID , $price , $vol , $priorTS , $ts , $remMsg ) = unpack ( "a12a9vaa8a8la8a8a*" , $msg );

		printf STDERR "Sym [%s] PO [%03d] Side [%s] ID [%.0f] price [%.4f] vol [%d] Priority TS[%s] TS [%s]\n" ,
						$sym , $po , $side , 
						parse8byteBinary ( $orderID ) , 
						parsePrice ( $price ) , $vol ,
						parseTS ( $priorTS ) , parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseAssignCOP {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Assign COP\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $cop , $side , $brkrInfo , $ts , $remMsg ) = unpack ( "a12a9a8aa150a8a*" , $msg );
		printf STDERR "Sym [%s] COP [%.4f] Side [%s] TS [%s]\n" ,
						$sym , parsePrice ( $cop ) , $side ,
						parseTS ( $ts );
		my ( @brkrInfo ) = ( $brkrInfo =~ /(.{10})/g );
		foreach ( @brkrInfo ) {
			my ( $po , $id ) = unpack ( "va8" , $_ );
			printf STDERR "...PO [%s] ID [%.0f]\n" ,
							$po , parse8byteBinary ( $id );
		}
		$msg = $remMsg;
	}
}

sub parseAssignCOPNoOrders {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Assign COP No Orders\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $cop , $ts , $remMsg ) = unpack ( "a12a9a8a8a*" , $msg );
		printf STDERR "Sym [%s] COP [%.4f] TS [%s]\n" ,
						$sym , parsePrice ( $cop ) ,
						parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseAssignLimit {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Assign Limit\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $cop , $side , $brkrInfo , $ts , $remMsg ) = unpack ( "a12a9a8aa270a8a*" , $msg );
		printf STDERR "Sym [%s] COP [%.4f] Side [%s] TS [%s]\n" ,
						$sym , parsePrice ( $cop ) , $side ,
						parseTS ( $ts );
		my ( @brkrInfo ) = ( $brkrInfo =~ /(.{18})/g );
		foreach ( @brkrInfo ) {
			my ( $po , $id , $price ) = unpack ( "va8a8" , $_ );
			printf STDERR "...PO [%s] ID [%.0f] Price [%.4f]\n" ,
							$po , parse8byteBinary ( $id ) , parsePrice ( $price );
		}
		$msg = $remMsg;
	}
}

sub parseMktStateUpdate {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Market State Update\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $state , $grp , $ts , $remMsg ) = unpack ( "a12aaa8a*" , $msg );
		printf STDERR "State [%s] Grp [%s] TS [%s]\n" ,
						$state , ord ( $grp ) , parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseTradeRpt {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Trade Report\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $tradeNo , $price , $vol , $buyPO , $buyOrderID , $buyDispVol , $sellPO , $sellOrderID , $sellDispVol ,
				$bypass , $trdTS , $crossType , $ts , $remMsg )
			= unpack ( "a12a9la8lsa8lsa8laa4aa8a*" , $msg );
		printf STDERR "Sym [%s] TradeNo [%d] Price [%.4f] Vol [%d] Bypass [%s] Cross Type [%s] Trd TS [%s] TS [%s]\n" ,
						$sym , $tradeNo ,
						parsePrice ( $price ) , $vol , $bypass , $crossType ,
						parseTS ( $trdTS ) , parseTS ( $ts );
		printf STDERR "...BUY PO [%03d] OrderID [%.0f] DispVol [%d] SELL PO [%03d] OrderID [%.0f] DispVol [%d]\n" ,
						$buyPO , parse8byteBinary ( $buyOrderID ) , $buyDispVol ,
						$sellPO , parse8byteBinary ( $sellOrderID ) , $sellDispVol;
		$msg = $remMsg;
	}
}
	
sub parseStockStatus {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Stock Status\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $comment , $state , $ts , $remMsg ) = unpack ( "a12a9a40a2a8a*" , $msg );
		printf STDERR "Sym [%s] State [%s] Comment [%s] TS [%s]\n" ,
						$sym , $state , $comment ,
						parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseTradeCxled {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Trade Cancelled\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $tradeNo , $ts , $remMsg ) = unpack ( "a12a9la8a*" , $msg );
		printf STDERR "Sym [%s] Trade No [%d] TS [%s]\n" ,
						$sym , $tradeNo ,
						parseTS ( $ts );
		$msg = $remMsg;
	}
}

sub parseTradeCorr {
	my ( $msg , $repeat ) = @_;
	print STDERR "Parse Trade Correction\n";
	for ( 0 .. $repeat - 1 ) {
		my ( $hdr , $sym , $tradeNo , $price , $vol , $buyPO , $sellPO , $initiator , $origTradeNo , 
				$bypass , $trdTS , $crossType , $ts , $remMsg ) 
			= unpack ( "a12a9la8lssalalaa8a*" , $msg );
		printf STDERR "Sym [%s] Trade No [%d] Price [%.4f] Vol [%d] Buy PO [%03d] Sell PO [%03d]\n" ,
						$sym , $tradeNo , parsePrice ( $price ) , 
						$vol , $buyPO , $sellPO;
		printf STDERR "Initiator [%s] Orig Trade No [%d] Bypass [%s] Cross Type [%s] Trade TS [%s] TS [%s]\n" ,
						$initiator , $origTradeNo , $bypass , $crossType ,
						parseTS ( $trdTS ) , parseTS ( $ts );
		$msg = $remMsg;
	}
}
	
sub hexDump {
	my ( $str ) = @_;
	return join ( " " , map { sprintf ( "%02x" , ord ( $_ ) ) } split ( // , $str ) );
}

sub new {
	my $class = shift;
	my $self = {
		msg		=> undef ,
		@_
	};

	bless $self;
	
	if ( $self->{msg} ) {
		$self->parseMsg;
	}
	return $self;
}

sub parseMsg {
	my $self = shift;
	my ( $msg ) = @_;
	$msg = $self->{msg} if !$msg;
	
	my ( $len , $hdr , $msgCont ) = unpack ( "x3va6a*" , $msg );
	my $cnt = ord ( unpack ( "x5a" , $hdr ) );
	
#	Peek inside the 1st hdr (which usually is the only header).
#	-----------------------------------------------------------
	$self->{msgType} = unpack ( "x2a" , $msgCont );
#	print STDERR "Msg [" , hexDump ( $msg ) , "] [" , hexDump ( $len ) , 
#				"] [" , hexDump ( $hdr ) , "] full len [" , length ( $msg ) , "] len [$len] cnt [$cnt] type [$msgType]\n";
	my $parser = $msgTypeMap{ $self->{msgType} }{ "Parser" };
	print STDERR "Msg [$msgTypeMap{ $self->{msgType} }{ 'Name' }] parser [$parser]\n";
	if ( $parser ) {
		&$parser ( $msgCont , $cnt );
	}
		
}

1;