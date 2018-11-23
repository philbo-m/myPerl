package STAMP::STAMPMsg;

use strict;
use Data::Dumper;

use STAMP::STAMPOrderMsg;
use STAMP::STAMPTradeMsg;
use STAMP::STAMPQuoteMsg;
use STAMP::STAMPSymStatusMsg;
use STAMP::STAMPMktStateMsg;
use STAMP::STAMPNLSPMsg;

use STAMPFld;

our %STAMPMsgMap = (
	OrderCancelResp 	=> "STAMPOrderMsg" ,
	IntOrderCancelResp	=> "STAMPOrderMsg" ,
	OrderInfo			=> { OrderBook => "STAMPOrderMsg" } ,
	TradeReport			=> "STAMPTradeMsg" ,
	IntQuote			=> "STAMPQuoteMsg" ,
	ABBOIntQuote		=> "STAMPQuoteMsg" ,
	SymbolInfo			=> "STAMPSymStatusMsg" ,
	MarketStateChange	=> "STAMPMktStateMsg" ,
	"NLSP-Notification"	=> "STAMPNLSPMsg"
	
);

our $busClassRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessClass } . "=([A-Za-z]+)";
our $busActionRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessAction } . "=([A-Za-z]+)";

sub fmtTimeStamp {
	my ( $ts ) = @_;

	$ts =~ s/^(\d{2})(\d{2})(\d{2})(\d+)$/$1:$2:$3.$4/;
	return $ts;
}

sub mkFldMap {
	my ( $rawMsg ) = @_;
	
 	$rawMsg = substr ( $rawMsg , 1 );
	my $fm = { split ( /[=\034\036]+/ , $rawMsg ) };
#	my $fm = { split ( /(?:=|\034|\036)+/ , $rawMsg , 1 ) };
	return $fm;
}

sub findAttr {
	my ( $rec , $attr , $idx ) = @_;
	
	return findNumAttr ( $rec , $STAMPFld::revTagMap{ $attr } , $idx );
}

sub findNumAttr {
	my ( $rec , $numAttr , $idx ) = @_;
	
	my $fullNumAttr = $numAttr . ( defined $idx ? ".$idx" : "" );
	my $str = "\036$fullNumAttr=";
	my $val = undef;
	my $pos = index ( $rec , $str );
	if ( $pos >= 0 ) {
		my $len = index ( substr ( $rec , $pos + length ( $str ) ) , "\036" );
		$val = substr ( $rec , $pos + length ( $str ) , $len );
	}
	return $val;
}

sub newSTAMPMsg {
	my ( $rawMsg ) = @_;	
	$rawMsg .= "\036";
	
	my $busClass = findAttr ( $rawMsg , "BusinessClass" );
	
#	if ( $busClass =~ /OrderCancelResp/ ) {
	if ( index ( $busClass , 'OrderCancelResp' ) >= 0 ) {
		return new STAMP::STAMPOrderMsg ( Rec => $rawMsg );
	}
	elsif ( $busClass eq 'OrderInfo' ) {
		my $busAct = findAttr ( $rawMsg , "BusinessAction" );
		if ( $busAct eq 'OrderBook' ) {
			return new STAMP::STAMPOrderMsg ( Rec => $rawMsg );
		}
	}
	elsif ( $busClass eq 'TradeReport' ) {
		return new STAMP::STAMPTradeMsg ( Rec => $rawMsg );
	}
	elsif ( $busClass =~ /IntQuote/ ) {
		return new STAMP::STAMPQuoteMsg ( Rec => $rawMsg );
	}
	elsif ( $busClass eq 'SymbolInfo' ) {
		my $busAct = findAttr ( $rawMsg , "BusinessAction" );
		if ( $busAct eq 'SymbolStatus' ) {
			return new STAMP::STAMPSymStatusMsg ( Rec => $rawMsg );
		}
	}	
	elsif ( $busClass eq 'StockStatus' ) {
		return new STAMP::STAMPSymStatusMsg ( Rec => $rawMsg );
	}	
	elsif ( $busClass eq 'MarketStateChange' ) {
		return new STAMP::STAMPMktStateMsg ( Rec => $rawMsg );
	}	
	elsif ( $busClass eq 'NLSP-Notification' ) {
		return new STAMP::STAMPNLSPMsg ( Rec => $rawMsg );
	}	
	else {
	}
	return undef;
}

sub new {
	my $class = shift;
	my %paramMap = @_;
	
	my $attribs = ( $paramMap{ Rec } ? mkFldMap( $paramMap{ Rec } ) : {} );
	my $self = {
		Attribs	=> $attribs
	};
	bless $self;

	my $overrides = $paramMap{ Attribs };
	if ( $overrides ) {
		foreach my $key ( keys %$overrides ) {
			$self->setAttr ( $key , $$overrides{ $key } );
		}
	}

	return $self;
}

sub init {
}

sub clone {
	my $self = shift;
	
	my %attribs = map { $_ => $self->{Attribs}{ $_ } } keys %{ $self->{Attribs} };
	my $newMsg = $self->new ();
	$newMsg->{Attribs} = \%attribs;
	return $newMsg;
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

sub getKeys {
	my $self = shift;
	
	return grep { ( my $k = $_ ) =~ s/\.[01]// ; exists $STAMPFld::tagMap{ $k } } keys %{ $self->{Attribs} };
}

sub getAttr {
	my $self = shift;
	my ( $attr , $idx ) = @_;

#	my $val;
	my $fullAttr = $STAMPFld::revTagMap{ $attr } . ( defined $idx ? ".$idx" : "" );

	my $val = $self->{Attribs}{ $fullAttr } if exists $self->{Attribs}{ $fullAttr };
	
#	Hack to strip leading YYYYMMDD component out of time stamp flds (and save it as the Date attribute).
#	----------------------------------------------------------------------------------------------------
	if ( $attr eq 'TimeStamp' ) {
		$self->setAttr ( "Date" , substr ( $val , 0 , 8 ) );	# --- side-effect of retrieving TimeStamp for the first time ---
		$val = substr ( $val , 8 );
	}
	
	return $val;
	
}

sub setAttr {
	my $self = shift;
	my ( $attr , $val , $idx ) = @_;
	
	if ( !exists $STAMPFld::revTagMap{ $attr } ) {
		STAMPFld::addTag ( $attr , $idx );
	}
	
	my $fullAttr = $STAMPFld::revTagMap{ $attr } . ( defined $idx ? ".$idx" : "" );
	return $self->{Attribs}{ $fullAttr } = $val;
}

sub collapseRec {
	my $self = shift;
	my ( $idx ) = @_;	# --- fld=val\036fld=val\036...\036 ---
	
	my %attribs = map { ( my $key = $_ ) =~ s/\..*$// ; $key => $self->{Attribs}->{$_} } grep { /^[0-9]+(?:\.${idx})?$/ } keys %{ $self->{Attribs} };
	
	return "\036" . join ( "\036" , map { "$_=$attribs{ $_ }" } keys %attribs );
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

