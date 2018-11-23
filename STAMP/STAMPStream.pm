package STAMP::STAMPStream;

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

use STAMP::STAMPMsg;

my $BUF_SIZE = 500;

sub new {
	my $class = shift;
	my $self = {
					File		=> undef ,
					SkipOrders	=> undef , 
					Quiet		=> undef ,
					RecordSep	=> $/ ,
					@_
				};


	if ( !$self->{File} ) {
		$self->{File} = "<STDIN>";
		$self->{FH} = *STDIN;
	}
	elsif ( !ref ( $self->{File} ) ) {
		open ( $self->{FH} , $self->{File} ) or die ( "Cannot open [$self->{File}] : $_" );
	}

#	For safety, validate the record separator.
#	------------------------------------------
	my $buf;
	my $bufSize = 1000;
	if ( read ( $self->{FH} ,$buf , $bufSize ) != $bufSize ) {
		die ( "Insufficient data in [$self->{File}]" );
	}
	if ( index ( $buf ,  $self->{RecordSep} ) < 0 ) {
		die ( "Record separator not found in [$self->{File}]" );
	}
	
	$self->{InputBuf} = $buf;

	$self->{ClOrdIDMap} = {};
	$self->{msgBuf} = [];
	$self->{msgMap} = {};
	
	return bless $self;
}

sub _addToMsgBuf {
	my $self = shift;
	my ( $msg ) = @_;
	
	unshift @{ $self->{msgBuf} } , $msg;	# --- reverse chronological order ---
}

sub _applyTrade {
	my $self = shift;
	my ( $trdMsg ) = @_;
#	print STDERR "_applyTrade [$trdMsg]...\n";

	
#	Occasionally a trade message is combined with the 2nd half of a CXL/Rebook.  Indicator is the presence
#	of a CFOdOrderNumber tag in the message.  If the CFO'd order is fully filled by the trade, then there will
#	NOT be a subsequent Rebook msg, so build and apply a synthetic one here.
#	----------------------------------------------------------------------------------------------------------
	if ( !$self->{ SkipOrders } ) {
		my $cfodOrderNo = $trdMsg->getAttr ( "CFOdOrderNumber" );
		if ( $cfodOrderNo ) {
	
#			Use the OrderNumber naming convention to determine the order side ('B....' = Buy ; 'S....' = Sell).
#			---------------------------------------------------------------------------------------------------
			my %bsMap = ( B => 0 , S => 1 );
			( my $bs = $cfodOrderNo ) =~ s/^(.).*$/$1/;
			my $bsIdx = $bsMap{ $bs };
			
			my $remVol = $trdMsg->getAttr ( "RemainingVolume" , $bsIdx );
			if ( $remVol == 0 ) {
		
#				CFO'd order is fully filled.  Make a "synthetic" order and patch its volume back to its pre-trade value.
#				--------------------------------------------------------------------------------------------------------		
				my $timeStamp = $trdMsg->timeStamp;
				print STDERR "STAMPStream : [$timeStamp] REBOOK IN TRADE [$cfodOrderNo] [$bs] [$bsIdx]...\n" if $self->{Debug};

				my $orderRawRec = $trdMsg->collapseRec ( $bsIdx );
				my %attrMap = (
						Volume	=> $trdMsg->getAttr ( "Volume" ) + $trdMsg->getAttr ( "RemainingVolume.${bsIdx}" )
					);
#				print STDERR "Synthetic order rec [$orderRawRec], attrMap = [" , Dumper ( \%attrMap ) , "]\n";
				my $orderMsg = new STAMP::STAMPOrderMsg ( Rec => $orderRawRec , Attribs => \%attrMap );
#				print STDERR Dumper ( $orderMsg ) , "\n";
			
				$self->_applyRebook ( $orderMsg , $trdMsg->getAttr ( "Symbol" ) ,
													$orderMsg->getAttr ( "BrokerNumber" ) ,
													$orderMsg->getRefOrderNo
									);
			}
		}
	}
	
	$self->_addToMsgBuf ( $trdMsg );
}

sub _applyRebook {
	my $self = shift;
	my ( $msg , $sym , $po , $refOrderNo ) = @_;
#	print STDERR "_applyRebook [" , Dumper ( $msg ) , "]...\n";

	my $cfodOrderNo = $msg->getAttr ( "CFOdOrderNumber" );
	my $clOrdID = $msg->getAttr ( "UserOrderId" );

	print STDERR "STAMPStream : 2nd half of CXL/Rbk: Looking for [$sym] [$po] [$cfodOrderNo] = [$self->{msgMap}{ $sym }{ $po }{ $cfodOrderNo }]...\n" if $self->{Debug};
	my $cfodOrder = delete $self->{msgMap}{ $sym }{ $po }{ $cfodOrderNo };
#	print STDERR "STAMPStream : Order to be CFOed : [" , Dumper ( $cfodOrder ) , "]\n";
	
	if ( !$cfodOrder && !$self->{ Quiet } ) {
		print STDERR "ERROR : STAMPStream : Cannot find orig order [$cfodOrderNo] for CFO [$sym] [" , $msg->dump () , "]\n";
	}
	else {
		$cfodOrder->applyCFO ( $msg );
		$self->{ClOrdIDMap}{ $sym }{ $po }{ $refOrderNo } = $clOrdID;
		
#		Rebook might actually be a kill.  
#		--------------------------------
		if ( $msg->isKilled ) {
			$cfodOrder->setToKilled;
			$cfodOrder->setAttr ( "UserOrderId" , $cfodOrder->getAttr ( "CFOdUserOrderId" ) );
			print STDERR "STAMPStream : Rebook/kill:\n" , Dumper ( $cfodOrder ) , "\n" if $self->{Debug};
		}
	}
}

sub _cacheCXL {
	my $self = shift;
	my ( $msg , $sym , $po , $refOrderNo ) = @_;
	
	my $orderNo = $msg->getAttr ( "OrderNumber" );
	
#	print STDERR "CACHING CXL [$sym] [$po] [$refOrderNo]...\n";
	$self->{msgMap}{ $sym }{ $po }{ $orderNo } = $msg;	# --- to be picked up by the 2nd half of the CXL-rebook, if any ---
				
#	Look up the order's original ClOrdID and if it's changed, save it in the message.
#	---------------------------------------------------------------------------------
	my $origClOrdID = delete $self->{ClOrdIDMap}{ $sym }{ $po }{ $refOrderNo };
	if ( !$origClOrdID && !$self->{ Quiet } ) {
		print STDERR "ERROR : STAMPStream : Cannot find original ClOrdID for CXL [$sym] [$po] [$refOrderNo]\n";
	}
	else {
		$msg->setAttr ( "CFOdUserOrderId" , $origClOrdID );
	}
}

sub _applyToMsgBuf {
	my $self = shift;
	my ( $msg ) = @_;
	
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
	
		return if $self->{ SkipOrders };
	
#		Skip on-stop orders (maybe just for now).
#		-----------------------------------------
		my $onStopPrice = $msg->getAttr ( "OnStopPrice" );
		return if $onStopPrice;
		
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );
		my $cfodOrderNo = $msg->getAttr ( "CFOdOrderNumber" );
		my $clOrdID = $msg->getAttr ( "UserOrderId" );
		my $refOrderNo = $msg->getRefOrderNo;
	
		if ( $cfodOrderNo ) {
		
#			2nd half of a CXL-rebook.
#			-------------------------
			$self->_applyRebook ( $msg , $sym , $po , $refOrderNo );
			my $cfoMsg = $msg->clone;
#			print STDERR "MSG [" , Dumper ( $msg ) , "]\nCFO MSG [" , Dumper ( $cfoMsg ) , "]\n";
			$msg = $cfoMsg;
		}
		else {
			if ( $msg->isCXL ) {
			
#				CXL.  Might be the 1st half of a CXL-rebook.  Cache the message in a buffer for future reference.
#				-------------------------------------------------------------------------------------------------
				$self->_cacheCXL ( $msg , $sym , $po , $refOrderNo );
			}
			else {
			
#				Brand new order.  Cache the ClOrdID for possible future carry forward in case the order is CFO'ed.
#				--------------------------------------------------------------------------------------------------
				$self->{ClOrdIDMap}{ $sym }{ $po }{ $refOrderNo } = $clOrdID;
			}
		
			$self->_addToMsgBuf ( $msg );		
		}
	}
	elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
		$self->_applyTrade ( $msg );
	}
	else {
		$self->_addToMsgBuf ( $msg );
	}
}

sub _popMsgBuf {
	my $self = shift;
	
	my $msg = pop @{ $self->{msgBuf} };
	return undef if !$msg;
	
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) && $msg->isCXL ) {
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );
		my $orderNo = $msg->getAttr ( "OrderNumber" );
		
		delete $self->{msgMap}{ $sym }{ $po }{ $orderNo };
	}

	return $msg;
}

sub next {
	my $self = shift;
	
	if ( ( !defined $self->{FH} ) && !@{ $self->{msgBuf} } ) {
		return undef;
	}
	
	$/ = $self->{RecordSep};
	
#	Deal with test input buffer first (from constructor).
#	------------------------------------------------------
	if ( $self->{InputBuf} ) {
#		print STDERR "INPUT BUF [$self->{InputBuf}]]...\n\n";
		while ( $self->{InputBuf} =~ m{^(.*?)$/(.*)$}s ) {
#			print STDERR "INPUT BUF MATCH [$1] [$2]...\n\n";
			my $msg = STAMP::STAMPMsg::newSTAMPMsg ( $1 );
			if ( $msg ) {
				$self->_applyToMsgBuf ( $msg );
			}
			$self->{InputBuf} = $2;
#			print STDERR "...Input buf now [$self->{InputBuf}]...\n";
		}
	}	

#	Read from the input file/stream from then on.
#	----------------------------------------------	
	if ( my $fh = $self->{FH} ) {
	
		while ( $#{ $self->{msgBuf} } < $BUF_SIZE ) {
			my $msg;
			
			while ( <$fh> ) {
				chomp;
				if ( $self->{InputBuf} ) {
#					print STDERR "...Last bit of input buf [$self->{InputBuf}]...\n";
					$_ = $self->{InputBuf} . $_;
					$self->{InputBuf} = undef;
				}
				$msg = STAMP::STAMPMsg::newSTAMPMsg ( $_ );
				if ( !( $. % 1000000 ) ) {
					print STDERR scalar ( localtime ( time () ) ) , " [" , ( $msg ? $msg->date . " " . $msg->timeStamp : "" ) , "] $....\n";
				}
				last if $msg;
			}
			last if !$msg;
			$self->_applyToMsgBuf ( $msg );
		}
	}
	
	return $self->_popMsgBuf;
}

1;