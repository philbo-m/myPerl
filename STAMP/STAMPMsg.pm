package STAMP::STAMPMsg;

use strict;
use Data::Dumper;

use STAMP::STAMPOrderMsg;
use STAMP::STAMPTradeMsg;
use STAMP::STAMPQuoteMsg;
use STAMP::STAMPSymStatusMsg;
use STAMP::STAMPStockInitMsg;
use STAMP::STAMPMktStateMsg;
use STAMP::STAMPNLSPMsg;
use STAMP::STAMPMOCImbalMsg;

use STAMPFld;

our %STAMPMsgMap = (
	OrderCancelResp 	=> "STAMPOrderMsg" ,
	IntOrderCancelResp	=> "STAMPOrderMsg" ,
	OrderInfo			=> { OrderBook => "STAMPOrderMsg" } ,
	TradeReport			=> "STAMPTradeMsg" ,
	IntQuote			=> "STAMPQuoteMsg" ,
	ABBOIntQuote		=> "STAMPQuoteMsg" ,
	SymbolInfo			=> { SymbolStatus => "STAMPSymStatusMsg" } ,
	StockInitialization	=> "STAMPStockInitMsg" ,
	StockStatus			=> "STAMPSymStatusMsg" ,
	MarketStateChange	=> "STAMPMktStateMsg" ,
	"NLSP-Notification"	=> "STAMPNLSPMsg" ,
	MocImbalanceStatus	=> "STAMPMOCImbalMsg"
);

our $busClassRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessClass } . "=([A-Za-z]+)";
our $busActionRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessAction } . "=([A-Za-z]+)";

sub fmtTimeStamp {
	my ( $ts ) = @_;

	$ts =~ s/^(\d{2})(\d{2})(\d{2})(\d+).*/$1:$2:$3.$4/;
	return $ts;
}

sub newSTAMPMsg {
	my ( $rawMsg ) = @_;
	$rawMsg .= "\036";

	my $msg = new STAMP::STAMPMsg ( Rec => $rawMsg );
	my $busClass = $msg->getAttr ( "BusinessClass" );
	
	my $msgClass = $STAMPMsgMap{ $busClass };
	return undef if !$msgClass;
	if ( ref $msgClass eq 'HASH' ) {
		my $busAct = $msg->getAttr ( "BusinessAction" );
		$msgClass = $STAMPMsgMap{ $busClass }{ $busAct };
		return undef if !$msgClass;
	}
	
	$msg = bless $msg , "STAMP::$msgClass";
	$msg->init ();
	return $msg;

#	--- BEGIN PROBABLE CRUFT ---	
	if ( index ( $busClass , 'OrderCancelResp' ) >= 0 ) {
		$msg = bless $msg , "STAMP::STAMPOrderMsg";
	}
	elsif ( $busClass eq 'OrderInfo' ) {
		my $busAct = $msg->getAttr ( "BusinessAction" );
		if ( $busAct eq 'OrderBook' ) {
			$msg = bless $msg , "STAMP::STAMPOrderMsg";
		}
	}
	elsif ( $busClass eq 'TradeReport' ) {
		$msg = bless $msg , "STAMP::STAMPTradeMsg";
	}
	elsif ( $busClass =~ /IntQuote/ ) {
		$msg = bless $msg , "STAMP::STAMPQuoteMsg";
	}
	elsif ( $busClass eq 'SymbolInfo' ) {
		my $busAct = $msg->getAttr ( "BusinessAction" );
		if ( $busAct eq 'SymbolStatus' ) {
			$msg = bless $msg , "STAMP::STAMPSymStatusMsg";
		}
	}	
	elsif ( $busClass eq 'StockStatus' ) {
		$msg = bless $msg , "STAMP::STAMPSymStatusMsg";
	}
	elsif ( $busClass eq 'StockInitialization' ) {
		$msg = bless $msg , "STAMP::STAMPStockInitMsg";
	}
	elsif ( $busClass eq 'MarketStateChange' ) {
		$msg = bless $msg , "STAMP::STAMPMktStateMsg";
	}	
	elsif ( $busClass eq 'NLSP-Notification' ) {
		$msg = bless $msg , "STAMP::STAMPNLSPMsg";
	}
	elsif ( $busClass eq 'MocImbalanceStatus' ) {
		$msg = bless $msg , "STAMP::STAMPMOCImbalMsg";
	}
	else {
		return undef;
	}
	
	$msg->init();
	return $msg;
#	--- END PROBABLE CRUFT ---
}

sub new {
	my $class = shift;
	my $self = {
		@_
	};
	return bless $self;
}

sub init {
}

sub clone {
	my $self = shift;
	
	my $new = $self->new ( Rec => $self->{Rec} );
	$new->init();
	return $new;
}	

sub timeStamp {
	my $self = shift;
	if ( !$self->getAttr ( "DispTimeStamp" ) ) {
		$self->setAttr ( "DispTimeStamp" , fmtTimeStamp ( $self->getAttr ( "TimeStamp" ) ) );
	}
	return $self->getAttr ( "DispTimeStamp" );
}

sub date {
	my $self = shift;
	my $date = $self->getAttr ( "Date" );
	if ( !$date ) {
		$self->getAttr ( "TimeStamp" );
		$date = $self->getAttr ( "Date" );
	}
	return $date;
}

sub getAttr {
	my $self = shift;
	my ( $attr , $idx ) = @_;

	my $fullAttr = $STAMPFld::revTagMap{ $attr };
	$fullAttr .= ".${idx}" if defined $idx;

	return $self->{Attribs}{ $fullAttr } if exists $self->{Attribs}{ $fullAttr };
	
	my $len = length ( $fullAttr );
	my $pos = index ( $self->{Rec} , "\036${fullAttr}=" );
	
	return undef if $pos < 0;

	$pos += $len + 2;	# --- skip over the attribute name plus leading delimiter and equals sign ---
	my $val = substr ( $self->{Rec} , $pos , index ( $self->{Rec} , "\036" , $pos ) - $pos );
		
#	Hack to strip leading YYYYMMDD component out of time stamp flds (and save it as the Date attribute).
#	----------------------------------------------------------------------------------------------------
	if ( $attr eq 'TimeStamp' ) {
		$self->setAttr ( "Date" , substr ( $val , 0 , 8 ) );	# --- side-effect of retrieving TimeStamp for the first time ---
		$val = substr ( $val , 8 );
	}

	return $self->{Attribs}{ $fullAttr } = $val;
#	return $val;
}

sub setAttr {
	my $self = shift;
	my ( $attr , $val , $idx ) = @_;
	
	my $fullAttr = $STAMPFld::revTagMap{ $attr };
	$fullAttr .= ".${idx}" if defined $idx;
	
#	--- Prepend the attribute to the record, effectively overwriting any previous incarnation ---
	$self->{Rec} = "\036${fullAttr}=${val}$self->{Rec}";
	
	return $self->{Attribs}{ $fullAttr } = $val;
#	return $val;
}

# Take a trade record, remove all entries indexed with an idx OTHER than the specified one,
# and remove the idx from the remaining entries.
# -----------------------------------------------------------------------------------------
sub collapseRec {
	my $self = shift;
	my ( $idx ) = @_;
	
	( my $rec = $self->{Rec} ) =~ s/[1-9][0-9]*\.[^${idx}]=.*?\036//g;
	$rec =~ s/\.${idx}=/=/g;
	
	return $rec;
}
	

sub getOrderNumber {
	my $self = shift;
	my ( $idx ) = @_;
	
	my $orderNo = $self->getAttr ( 'PrivateOrderNumber' , $idx );
	return ( $orderNo ? $orderNo : $self->getAttr ( 'OrderNumber' , $idx ) );
}

sub dump {
	my $self = shift;
	
	return join ( " " , map { "$_=$self->{Attribs}{ $_ }" } keys %{ $self->{Attribs} } );
}

1;

