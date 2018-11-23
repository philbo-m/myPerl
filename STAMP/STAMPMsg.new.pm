package STAMP::STAMPMsg;

use strict;
use Data::Dumper;

use STAMP::STAMPOrderMsg;
use STAMP::STAMPTradeMsg;
use STAMP::STAMPQuoteMsg;
use STAMP::STAMPSymStatusMsg;
use STAMP::STAMPMktStateMsg;

use STAMPFld;

our %STAMPMsgMap = (
	OrderCancelResp 	=> "STAMPOrderMsg" ,
	IntOrderCancelResp	=> "STAMPOrderMsg" ,
	OrderInfo			=> { OrderBook => "STAMPOrderMsg" } ,
	TradeReport			=> "STAMPTradeMsg" ,
	IntQuote			=> "STAMPQuoteMsg" ,
	ABBOIntQuote		=> "STAMPQuoteMsg" ,
	SymbolInfo			=> "STAMPSymStatusMsg" ,
	MarketStateChange	=> "STAMPMktStateMsg"
);

our $busClassRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessClass } . "=([A-Za-z]+)";
our $busActionRE = "[^0-9]" . $STAMPFld::revTagMap{ BusinessAction } . "=([A-Za-z]+)";

sub fmtTimeStamp {
	my ( $ts ) = @_;
	$ts =~ s/^(\d{2})(\d{2})(\d{2})(\d+)$/$1:$2:$3.$4/;
	return $ts;
}

sub mkFldMap {
	my ( $rawMsg ) = $_;
	
	my ( $pos , $ppos ) = ( -1 , -1 );
	my %fldMap;
	while ( ( $pos = index ( $_ , "\036" , $pos + 1 ) ) != -1 ) {
		if ( $ppos != -1 ) {
			my $eqIdx = index ( $_ , "=" , $ppos + 1 );
			$fldMap{ substr ( $_ , $ppos + 1 , $eqIdx - $ppos - 1 ) } = substr ( $_ , $eqIdx + 1 , $pos - $eqIdx - 1 );
		}
		$ppos = $pos;
	}	
	return \%fldMap;
}

sub findAttr {
	my ( $rec , $attr ) = @_;
	
	my ( $key , $idx ) = split /\./ , $attr;
	my $numKey = $STAMPFld::revTagMap{ $key } . ( $idx eq '' ? "" : ".$idx" );	

	my $str = "\036$numKey=";
	my $val = undef;
	my $pos = index ( $rec , $str );
	if ( $pos >= 0 ) {
		my $len = index ( substr ( $rec , $pos + length ( $str ) ) , "\036" );
		$val = substr ( $rec , $pos + length ( $str ) , $len );
	}
	return $val;
}

sub xnewSTAMPMsg {
	my ( $rawMsg ) = @_;
	
	$rawMsg =~ m/$busClassRE/;
	my $busClass = $1;
	my $msgType = $STAMPMsgMap{ $busClass };
#	print STDERR "[$busClass] [$msgType]...\n";
	return undef if !$msgType;
	
	if ( ref $msgType eq 'HASH' ) {
		$rawMsg =~ m/$busActionRE/;
		my $busAction = $1;
		$msgType = $$msgType{ $busAction };
#		print STDERR "...[$busAction] [$msgType]...\n";
		return undef if !$msgType;
	}
	
	my $fldMap = mkFldMap ( $rawMsg );
	my $STAMPMsg = eval "new STAMP::$msgType ( Attribs => \$fldMap , ChopTimestamp => 1 )";
#	print STDERR "[$busClass] [$STAMPMsg]\n";
	return $STAMPMsg;

}

sub newSTAMPMsg {
	my ( $rawMsg ) = @_;
			
	my $busClass = findAttr ( $rawMsg , "BusinessClass" );
	
	if ( $busClass =~ /OrderCancelResp/ ) {
		return new STAMP::STAMPOrderMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass } );
	}
	elsif ( $busClass eq 'OrderInfo' ) {
		my $busAct = findAttr ( $rawMsg , "BusinessAction" );
		if ( $busAct eq 'OrderBook' ) {
			return new STAMP::STAMPOrderMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass , BusinessAction => $busAct } );
		}
	}
	elsif ( $busClass eq 'TradeReport' ) {
		return new STAMP::STAMPTradeMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass }  );
	}
	elsif ( $busClass =~ /IntQuote/ ) {
		return new STAMP::STAMPQuoteMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass }  );
	}
	elsif ( $busClass eq 'SymbolInfo' ) {
		my $busAct = findAttr ( $rawMsg , "BusinessAction" );
		if ( $busAct eq 'SymbolStatus' ) {
			return new STAMP::STAMPSymStatusMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass , BusinessAction => $busAct } );
		}
	}	
	elsif ( $busClass eq 'StockStatus' ) {
		return new STAMP::STAMPSymStatusMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass }  );
	}	
	elsif ( $busClass eq 'MarketStateChange' ) {
		return new STAMP::STAMPMktStateMsg ( Rec => $rawMsg , Attribs => { BusinessClass => $busClass }  );
	}	
	else {
	}
	return undef;
}

sub new {
	my $class = shift;
	my $self = {
		Rec		=> undef ,
		Attribs	=> {} ,
		@_
	};

	return bless $self;
}

sub clone {
	my $self = shift;
	
	my %attribs = map { $_ => $self->{Attribs}{ $_ } } keys %{ $self->{Attribs} };
	return $self->new ( Rec => $self->{Rec} , Attribs => \%attribs );
}	

sub timeStamp {
	my $self = shift;
	if ( !$self->getAttr ( "DispTimeStamp" ) ) {
		$self->setAttr ( "DispTimeStamp" , fmtTimeStamp ( $self->getAttr ( "TimeStamp" ) ) );
	}
	return $self->getAttr ( "DispTimeStamp" );
}

sub getKeys {
	my $self = shift;
	
	return grep { ( my $k = $_ ) =~ s/\.[01]// ; exists $STAMPFld::tagMap{ $k } } keys %{ $self->{Attribs} };
}

sub getAttr {
	my $self = shift;
	my ( $attr , $mustExist ) = @_;

	return $self->{Attribs}{ $attr } if exists $self->{Attribs}{ $attr };
	
	my $val = findAttr ( $self->{Rec} , $attr );
	if ( $val eq undef && $mustExist ) {
		print STDERR "Attrib [$attr] does not exist\n";
	}
	
#	Hack to strip leading YYYYMMDD component out of time stamp flds, and the trailing char from TimeStamp.
#	------------------------------------------------------------------------------------------------------
	if ( $attr =~ /timestamp/i ) {
		$val = substr ( $val , 8 );
		if ( $attr eq 'TimeStamp' ) {
			chop $val;
		}
	}
	
	return $self->{Attribs}{ $attr } = $val;
	
}

sub setAttr {
	my $self = shift;
	my ( $attr , $val ) = @_;
	
	return $self->{Attribs}{ $attr } = $val;
}

sub getOrderNumber {
	my $self = shift;
	my ( $idx ) = @_;
	
	my $key = 'OrderNumber' . ( $idx eq '' ? '' : ".$idx" );
	my $orderNo = $self->getAttr ( 'Private' . $key );
	return ( $orderNo ? $orderNo : $self->getAttr ( $key ) );
}

sub dump {
	my $self = shift;
	
	return join ( " " , map { "$_=$self->{Attribs}{ $_ }" } keys %{ $self->{Attribs} } );
}

1;

