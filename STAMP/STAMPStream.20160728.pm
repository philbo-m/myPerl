package STAMP::STAMPStream;

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;
use parent "STAMP::STAMPMsg";

my $BUF_SIZE = 500;

sub new {
	my $class = shift;
	my $self = {
					file => undef ,
					msgBuf => [] ,
					msgMap => {} ,
					@_
				};


	if ( !$self->{file} ) {
		$self->{fh} = *STDIN;
	}
	elsif ( !ref ( $self->{file} ) ) {
		open ( $self->{fh} , $self->{file} ) or die ( "Cannot open [$self->{file}] : $_" );
	}
	
	$self->{ClOrdIDMap} = {};
	
	return bless $self;
}

sub _applyToMsgBuf {
	my $self = shift;
	my ( $msg ) = @_;
	
	my $timeStamp = $msg->getAttr ( "TimeStamp" );
	print STDERR "[$.] [$timeStamp] [" , ref $msg , "]...\n";
				
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
	
#		Skip on-stop orders (maybe just for now).
#		-----------------------------------------
		my $onStopPrice = $msg->getAttr ( "OnStopPrice" );
		return if $onStopPrice;
		
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );
		my $orderNo = $msg->getAttr ( "OrderNumber" );
		my $cfodOrderNo = $msg->getAttr ( "CFOdOrderNumber" );
		my $clOrdID = $msg->getAttr ( "UserOrderId" );
		
		my $confType = $msg->getAttr ( "ConfirmationType" );
		my $pvtConfType = $msg->getAttr ( "PrivateConfirmationType" );
		
		print STDERR "[$.] : Processing [$po] [$orderNo] [$cfodOrderNo] [$clOrdID]...\n";
		
#		if ( $confType eq 'Accepted' && $pvtConfType eq 'Cancelled' ) {
#			print STDERR "...Discarding - active order already processed...\n";
#			return;
#		}
		
#		print STDERR "Adding [" , Dumper ( $msg ) , "]...\n";
		
		if ( $cfodOrderNo ) {
		
#			2nd half of a CXL-rebook.
#			-------------------------
			print STDERR "2nd half of CXL/Rbk: Looking for [$sym] [$po] [$cfodOrderNo] = [$self->{msgMap}{ $sym }{ $po }{ $cfodOrderNo }]...\n";
			my $cfodOrder = delete $self->{msgMap}{ $sym }{ $po }{ $cfodOrderNo };
			if ( !$cfodOrder ) {
				print STDERR "Cannot find orig order [$cfodOrderNo] for CFO [$sym] [ [" , $msg->dump () , "]\n";
			}
			else {
				$cfodOrder->applyCFO ( $msg );
				
				my $chkClOrdID = delete $self->{ClOrdIDMap}{ $sym }{ $po }{ $cfodOrderNo };
				$self->{ClOrdIDMap}{ $sym }{ $po }{ $orderNo } = $clOrdID;
			}
		}
		else {
			unshift @{ $self->{msgBuf} } , $msg;	# --- reverse chronological order ---
			
			if ( $msg->isCXL ) {
			
#				CXL.  Might be the 1st half of a CXL-rebook.  Cache the message in a buffer for future reference.
#				-------------------------------------------------------------------------------------------------
				my $refOrderNo = $orderNo;
				my $origClOrdID = delete $self->{ClOrdIDMap}{ $sym }{ $po }{ $refOrderNo };
				if ( !$origClOrdID ) {
					$refOrderNo = $msg->getAttr ( "PrivateOrderNumber" );
					$origClOrdID = delete $self->{ClOrdIDMap}{ $sym }{ $po }{ $refOrderNo };
					if ( !$origClOrdID ) {
						print STDERR "Cannot find [$sym] [$po] [$refOrderNo] in ClOrdID map...\n";
					}
				}
				print STDERR "[" , $msg->getAttr ( "TimeStamp" ) , "] : CXLing [$sym] [$po] [$refOrderNo] [$origClOrdID]...\n";
				print STDERR "1st half of CXL/Rbk : Added [$sym] [$po] [$orderNo] = [$msg] to msg map...\n";
				$self->{msgMap}{ $sym }{ $po }{ $orderNo } = $msg;	# --- to be picked up by the 2nd half of the CXL-rebook ---
				$msg->setAttr ( "CFOdUserOrderId" , $origClOrdID );
				$self->{ClOrdIDMap}{ $sym }{ $po }{ $orderNo } = $clOrdID;	

			}
			else {
			
#				Brand new order.
#				----------------
				$self->{ClOrdIDMap}{ $sym }{ $po }{ $orderNo } = $clOrdID;
			}
		}
#		print STDERR "ClOrdIDMap now : [" , Dumper ( $self->{ClOrdIDMap} ) , "]\n";
	}
	else {
		unshift @{ $self->{msgBuf} } , $msg;	# --- reverse chronological order ---
	}
}

sub _popMsgBuf {
	my $self = shift;
	
	my $msg = pop @{ $self->{msgBuf} };
	return undef if !$msg;
	
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
		my $po = $msg->getAttr ( "BrokerNumber" );
		my $sym = $msg->getAttr ( "Symbol" );
		my $orderNo = $msg->getAttr ( "OrderNumber" );
		
		if ( $msg->isCXL ) {
			print STDERR "Popping... removing [$sym] [$po] [$orderNo]...\n";
			delete $self->{msgMap}{ $sym }{ $po }{ $orderNo };
		}
	}
	return $msg;
}

sub next {
	my $self = shift;
	
	if ( ( !defined $self->{fh} ) && !@{ $self->{msgBuf} } ) {
		return undef;
	}
	
	if ( my $fh = $self->{fh} ) {
		for ( scalar @{ $self->{msgBuf} } .. $BUF_SIZE ) {
			my $msg;
			while ( <$fh> ) {
				print STDERR "$.\n" if ( !( $. % 100000 ) );
				chomp;
				$msg = STAMP::STAMPMsg::newSTAMPMsg ( $_ );
#				print STDERR "[$.] : [$_] [$msg]...\n";
				last if $msg;
			}
			last if !$msg;
			$self->_applyToMsgBuf ( $msg );
#			print STDERR "...Msg buf now [" , scalar @{ $self->{msgBuf} } , "] recs...\n";
		}
	}
	
#	print STDERR "Popping from [" , scalar @{ $self->{msgBuf} } , "] recs...\n";
	return $self->_popMsgBuf;
}

1;