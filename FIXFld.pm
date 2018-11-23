package FIXFld;

use strict;

our %tagMap = (
	1		=> 'Account' ,
	6		=> 'AvgPx' ,
	7		=> 'BeginSeqNo' ,
	8		=> 'BeginString' ,
	9		=> 'BodyLength' ,
	10		=> 'CheckSum' ,
	11		=> 'ClOrdID' ,
	14		=> 'CumQty' ,
	15		=> 'Currency' ,
	16		=> 'EndSeqNo' ,
	17		=> 'ExecID' ,
	18		=> 'ExecInst' ,
	19		=> 'ExecRefID' ,
	20		=> 'ExecTransType' ,
	21		=> 'HandlInst' ,
	22		=> 'IDSource' ,
	30		=> 'LastMkt' ,
	31		=> 'LastPx' ,
	32		=> 'LastShares' ,
	34		=> 'MsgSeqNum' ,
	35		=> 'MsgType' ,
	36		=> 'NewSeqNo' ,
	37		=> 'OrderID' ,
	38		=> 'OrderQty' ,
	39		=> 'OrdStatus' ,
	40		=> 'OrdType' ,
	41		=> 'OrigClOrdID' ,
	43		=> 'PossDupFlag' ,
	44		=> 'Price' ,
	45		=> 'RefSeqNum' ,
	47		=> 'Rule80A' ,
	48		=> 'SecurityID' ,
	49		=> 'SenderCompID' ,
	50		=> 'SenderSubID' ,
	52		=> 'SendingTime' ,
	54		=> 'Side' ,
	55		=> 'Symbol' ,
	56		=> 'TargetCompID' ,
	57		=> 'TargetSubID' ,
	58		=> 'Text' ,
	59		=> 'TimeInForce' ,
	60		=> 'TransactTime' ,
	63		=> 'SettlmntTyp' ,
	64		=> 'FutSettDate' ,
	65		=> 'SymbolSfx' ,
	76		=> 'ExecBroker' ,
	97		=> 'PossResend' ,
	98		=> 'EncryptMethod' ,
	99		=> 'StopPx' ,
	100		=> 'ExDestination' ,
	102		=> 'CxlRejReason' ,
	103		=> 'OrdRejReason' ,
	108		=> 'HeartBtInt' ,
	109		=> 'ClientID' ,
	110		=> 'MinQty' ,
	111		=> 'MaxFloor' ,
	112		=> 'TestReqID' ,
	114		=> 'LocateReqd' ,
	115		=> 'OnBehalfOfCompID' ,
	122		=> 'OrigSendingTime' ,
	123		=> 'GapFillFlag' ,
	126		=> 'ExpireTime' ,
	128		=> 'DeliverToCompID' ,
	132		=> 'BidPx' ,
	133		=> 'OfferPx' ,
	150		=> 'ExecType' ,
	151		=> 'LeavesQty' ,
	198		=> 'SecondaryOrderID' ,
	207		=> 'SecurityExchange' ,
	231		=> 'ContractMultiplier' ,
	308		=> 'UnderlyingSecurityExchange' ,
	336		=> 'TradingSessionID' ,
	347		=> 'MessageEncoding' ,
	369		=> 'LastMsgSeqNumProcessed' ,
	371		=> 'RefTagID' ,
	372		=> 'RefMsgType' ,
	373		=> 'SessionRejectReason' ,
	375		=> 'ContraBroker' ,
	378		=> 'ExecRestatementReason' ,
	379		=> 'BusinessRejectRefID' ,
	380		=> 'BusinessRejectReason' ,
	382		=> 'NoContraBrokers' ,
	383		=> 'MaxMessageSize' ,
	384		=> 'NoMsgTypes' ,
	385		=> 'MsgDirection' ,
	386		=> 'NoTradingSessions' ,
	432		=> 'ExpireDate' ,
	434		=> 'CxlRejResponseTo' ,
	554		=> 'Password' ,
	6005	=> 'TCMConstraints' ,
	6750	=> 'TSXAccountType' ,
	6751	=> 'TSXUserID' ,
	6754	=> 'TSXBasketTrade' ,
	6755	=> 'TSXProgramTrade' ,
	6757	=> 'TSXJitney' ,
	6759	=> 'TSXMGFCandidate' ,
	6760	=> 'TSXActionSource' ,
	6761	=> 'TSXAnonymous' ,
	6762	=> 'TSXExchangeUserID' ,
	6763	=> 'TSXRegulationID' ,
	6765	=> 'TSXReferenceVolume' ,
	6767	=> 'TSXBuyAccountType' ,
	6768	=> 'TSXSellAccountType' ,
	6769	=> 'TSXBuyAccountID' ,
	6770	=> 'TSXSellAccountID' ,
	6771	=> 'TSXBuyRegulationID' ,
	6772	=> 'TSXSellRegulationID' ,
	6773	=> 'TSXCrossType' ,
	6774	=> 'TSXBrokerNumber' ,
	6775	=> 'TSXATSName' ,
	6776	=> 'TSXPrincipalTrade' ,
	6777	=> 'TSXWashTrade' ,
	6778	=> 'TSXTradeCorrection' ,
	6779	=> 'TSXErrorNumber' ,
	6780	=> 'TSXExchangeAdmin' ,
	6781	=> 'TSXBuyJitney' ,
	6782	=> 'TSXSellJitney' ,
	6783	=> 'TSXNonResident' ,
	6784	=> 'TSXRTAutofill' ,
	6785	=> 'TSXBuyParticipation' ,
	6786	=> 'TSXSellParticipation' ,
	6788	=> 'TSXSpreadGoal' ,
	6789	=> 'TSXMessageId' ,
	6790	=> 'TSXOrderKey' ,
	6791	=> 'TSXByPass' ,
	6792	=> 'TSXNCIB' ,
	6794	=> 'TSXCustomerType' ,
	6795	=> 'TSXOrigTradeID' ,
	6796	=> 'TSXPrivateOrigPrice' ,
	6797	=> 'TSXBuyCustomerType' ,
	6798	=> 'TSXSellCustomerType' ,
	6820	=> 'Protection' ,
	6821	=> 'ProtectionPriceImprovement' ,
	7710	=> 'TSXSOROrderID1' ,
	7711	=> 'TSXSOROrderID2' ,
	7713	=> 'TSXNoTradeFeat' ,
	7714	=> 'TSXNoTradeKey' ,
	7715	=> 'TSXNoTradeOrderNum' ,
	7716	=> 'TSXNoTradeVol' ,
	7717	=> 'TSXNoTradePrice' ,
	7718	=> 'RESERVED' ,
	7719	=> 'TSXBuyParticipationVolume' ,
	7720	=> 'TSXSellParticipationVolume' ,
	7721	=> 'TSXRemainingBuyParticipationVolume' ,
	7722	=> 'TSXRemainingSellParticipationVolume' ,
	7723	=> 'TSXPegType' ,
	7726	=> 'TSXUndisplayed' ,
	7727	=> 'TSXExecCancelledReason' ,
	7729	=> 'ShortMarkingExempt' ,
	7734	=> 'TSXSpeedbump' ,
	7735	=> 'TSXLongLife' ,
	9479	=> 'Visible'
);

my $timeRegExp = '\\d{8}-\\d{2}:\\d{2}:\\d{2}\\.\\d{3}';
my $pxRegExp = '\\d+\\.\\d+';
my $oneCharRegExp = '.';
my $intRegExp = '\d+';

my %fldPtrnMap = (
	1		=> '[A-Za-z\\d][A-Za-z\\d]+' ,
	6		=> $pxRegExp ,
	7		=> $intRegExp , 
	16		=> $intRegExp , 
	21		=> '[156]' ,
	31		=> $pxRegExp ,
	39		=> $oneCharRegExp ,
	44		=> $pxRegExp ,
	52		=> $timeRegExp ,
	60		=> $timeRegExp ,
	99		=> $pxRegExp ,
	132		=> $pxRegExp ,
	133		=> $pxRegExp ,
	150		=> $oneCharRegExp ,
	6796	=> $pxRegExp ,
	7717	=> $pxRegExp
);

my %TSXAcctTypeMap = (
	NC	=> 'Non-client' ,
	CL	=> 'Client' ,
	ST	=> 'Equities specialist' ,
	IN	=> 'Inventory' ,
	MP	=> 'ME pro order' ,
	OF	=> 'Options firm account' ,
	OT	=> 'Options market maker'
);

my %TSXRegIdMap = (
	IA	=> 'Insider Account' ,
	NA	=> 'Not Applicable' ,
	SS	=> 'Significant Shareholder'
);

my %toMktMap = map { $_ => 1 } qw ( D F G );

our %valMap = (
	18		=> {
					0	=> 'Stay on offer side' ,
					1	=> 'Stay on bid side' ,
					9	=> 'Post on Bid' ,
					G	=> 'All or None' ,
					M	=> 'Mid-point Peg' ,
					P	=> 'Market Peg' ,
					R	=> 'Primary Peg'
				} ,
	20		=> {
					0	=> 'New' ,
					1	=> 'Cancel' ,
					2	=> 'Correct' ,
					3	=> 'Status' ,
					4	=> 'Market Command'
				} ,
	21		=> {
					1	=> 'Default/DAO' ,
					5	=> 'Kill/Cancel' ,
					6	=> 'Reprice'
				} ,
	35		=> {
					0	=> 'Heartbeat' ,
					1	=> 'Test Request' ,
					2	=> 'Resend Request' ,
					3	=> 'Reject' ,
					4	=> 'Sequence Reset' ,
					5	=> 'Logout' ,
					8	=> 'Execution Report' ,
					9	=> 'Order Cancel Reject' ,
					A	=> 'Logon' ,
					D	=> 'Single Order' ,
					F	=> 'Order Cancel Request' ,
					G	=> 'Order Cancel/Replace' ,
					MC	=> 'MarketCommand' ,
					MR	=> 'MarketCommandResp' ,
					f	=> 'SecurityStatus' ,
					j	=> 'Business Message Reject'
				} ,
	39		=> {
					0	=> 'New' ,
					1	=> 'Partially Filled' ,
					2	=> 'Filled' ,
					4	=> 'Cancelled' ,
					5	=> 'Replaced' ,
					6	=> 'Pending Cancel' ,
					8	=> 'Rejected' ,
					9	=> 'Suspended' ,
					A	=> 'Pending New' ,
					E	=> 'Pending Replace'
				} ,
	40		=> {
					1	=> 'Market' ,
					2	=> 'Limit' ,
					4	=> 'Stop Limit' ,
					5	=> 'Market on Close' ,
					B	=> 'Limit on Close' ,
					P	=> 'Pegged' ,
					X	=> 'Must Be Filled'
				} ,
	54		=> {
					1	=> 'Buy' ,
					2	=> 'Sell' ,
					5	=> 'Sell Short' ,
					6	=> 'Sell Short Exempt' ,
					8	=> 'Cross' ,
					9	=> 'Cross Short' ,
					A	=> 'Cross Short Exempt' ,
					P	=> 'Participation' ,
					M	=> 'DelayedOpenStock' ,
					R	=> 'RTAlert'
				} ,
	59		=> {
					0	=> 'Day' ,
					1	=> 'GTC' ,
					3	=> 'IOC' ,
					4	=> 'FOK' ,
					6	=> 'GTD' ,
					7	=> 'At the Close'	# --- Aequitas ---
				} ,
	63		=> {
					1	=> 'Cash' ,
					2	=> 'Next Day' ,
					6	=> 'Future' ,
					11	=> 'Non-Net' ,
					12	=> 'MS'
				} ,
	98		=> {
					0	=> 'None' ,
					1	=> 'PKCS' ,
					2	=> 'DES' ,
					3	=> 'PKCS/DES' ,
					4	=> 'PGP/DES'
				} ,
	103		=> {
					1	=> 'Unknown symbol' ,
					5	=> 'Unknown order'
				} ,
	150		=> {
					0	=> 'New' ,
					1	=> 'Partial Fill' ,
					2	=> 'Fill' ,
					3	=> 'Done For Day' ,
					4	=> 'Cancelled' ,
					5	=> 'Replaced' ,
					6	=> 'Pending Cancel' ,
					8	=> 'Rejected' ,
					9	=> 'Suspended' ,
					A	=> 'Pending New' ,
					D	=> 'Restated' ,
					E	=> 'Pending Replace' ,
					F	=> 'Trade' ,
					G	=> 'Trade Correct' ,
					H	=> 'Trade Cancel' ,
					I	=> 'Order Status'
				} ,
	372		=> {
					0	=> 'Heartbeat' ,
					1	=> 'Test Request' ,
					2	=> 'Resend Request' ,
					3	=> 'Reject' ,
					4	=> 'Sequence Reset' ,
					5	=> 'Logout' ,
					8	=> 'Execution Report' ,
					9	=> 'Order Cancel Reject' ,
					A	=> 'Logon' ,
					D	=> 'Single Order' ,
					F	=> 'Order Cancel Request' ,
					G	=> 'Order Cancel/Replace' ,
					MC	=> 'Market Command'
				} ,
	373		=> {
					0	=> 'Invalid tag number' ,
					1	=> 'Required tag missing' ,
					2	=> 'Tag not defined for this message type' ,
					3	=> 'Undefined tag' ,
					4	=> 'Tag specified without a value' ,
					5	=> 'Value is incorrect/out of range for this tag' ,
					6	=> 'Incorrect data format for this value' ,
					7	=> 'Decryption problem' ,
					8	=> 'Signature problem' ,
					9	=> 'CompID problem' ,
					10	=> 'SendingTime accuracy problem' ,
					11	=> 'Invalid MsgType'
				} ,
	378		=> {
					3	=> 'Repricing of Order' ,
					16	=> 'Booked' ,
					17	=> 'AssignTimePriority' ,
					18	=> 'Triggered' 
				} ,
	424		=> {
					1	=> 'Order Cancel Request' ,
					2	=> 'Order Cancel Replace Request'
				} ,
	6750	=> \%TSXAcctTypeMap ,
	6763	=> \%TSXRegIdMap ,
	6767	=> \%TSXAcctTypeMap ,
	6768	=> \%TSXAcctTypeMap ,
	6771	=> \%TSXRegIdMap ,
	6772	=> \%TSXRegIdMap ,
	6773	=> {
					B	=> 'Basis' ,
					C	=> 'Contingent' ,
					I	=> 'Internal' ,
					S	=> 'Special Trading Session' ,
					V	=> 'VWAP'
				} ,
	6784	=> {
					A	=> 'Oddlot' ,
					C	=> 'Closing' ,
					G	=> 'Guaranteed Fill' ,
					P	=> 'Participation'
				} ,
	7723	=> {
					M	=> 'NBBO midpoint' ,
					N	=> 'None'
				}
);

sub new {
	my $class = shift;
	
	my ( $tag , $val ) = @_;
	
	my ( $pfx , $timeStamp );
	if ( $tag =~ /^(.*)\s+(\d+)$/ ) {
		$pfx = $1;
		$tag = $2;
		
		if ( $pfx =~ /(\d{2}:\d{2}:\d{2}\.[\d_]+)/ ) {
			( $timeStamp = $1 ) =~ s/_//g;
		}
	}

	my $self = {
		tag			=> $tag ,
		val			=> $val ,
		pfx			=> $pfx ,
		timeStamp	=> $timeStamp
	};

	return bless $self;
}

sub isToMkt {
	my $self = shift;
	
	return ( exists $toMktMap{ $self->{val} } );
}

sub desc {
	my $self = shift;

	return "[$self->{tag}]$tagMap{ $self->{tag} }";
}

sub descVal {
	my $self = shift;
	
	my $val = $self->{val};
	if ( exists $valMap{ $self->{tag} } ) {
		$val .= " ($valMap{ $self->{tag} }{ $self->{val} })";
	}
	
	return $val;
}

sub cmp {
	my $self = shift;
	my ( $otherFld , $ignoreTrailingZeros ) = @_;

	my ( $val , $otherVal ) = ( $self->{val} , $otherFld->{val} );
	
	my $retVal = ( $val cmp $otherVal );
	if ( $retVal && $ignoreTrailingZeros 
		&& ( $val =~ /^${otherVal}\.?0*$/ || $otherVal =~ /^${val}\.?0*$/ ) ) {
		$retVal = 0;
	}
	return $retVal;
}

sub dump {
	my $self = shift;
	my ( $raw ) = @_;

	my $str;
	if ( !$raw ) {
		$str = ( $self->{pfx} ? "[$self->{pfx}]\n" : "" );
		$str .= $self->desc;
		if ( defined $self->{val} ) {
			$str .= " = " . $self->descVal;
		}
	}
	else {
		$str = defined $self->{val} ? $self->{val} : "";
	}
	
	return $str;
}

1;