package STAMPFld;

use strict;

our %tagMap = (
	1		=> "AccountId" ,
	2		=> "AccountType" ,
	5		=> "BusinessAction" ,
	6		=> "BusinessClass" ,
	7		=> "BuyAccountId" ,
	8		=> "BuyAccountType" ,
	10		=> "BuyOrderNumber" ,
	11		=> "CFOdOrderNumber" ,
	16		=> "ConfirmationType" ,
	17		=> "DestAddress" ,
	25		=> "Jitney" ,
	29		=> "MD5MessageAuth" ,
	30		=> "MGF-Candidate" ,
	32		=> "NewOrderNumber" ,
	35		=> "OnStopPrice" ,
	39		=> "OrderDuration" ,
	40		=> "OrderNumber" ,
	41		=> "Price" ,
	42		=> "BasketTrade" ,
	45		=> "SellAccountId" ,
	46		=> "SellAccountType" ,
	48		=> "SellOrderNumber" ,
	49		=> "MGF-Volume" ,
	50		=> "SequenceNumber" ,
	53		=> "SettlementTerms" ,
	54		=> "SourceAddress" ,
	55		=> "Symbol" ,
	56		=> "TimeStamp" ,
	57		=> "TradingSysTimeStamp" ,
	58		=> "Currency" ,
	62		=> "UserId" ,
	64		=> "Volume" ,
	70		=> "BrokerNumber" ,
	71		=> "PrincipalTrade" ,
	72		=> "RemainingVolume" ,
	75		=> "ActionSource" ,
	80		=> "StockHaltDate" ,
	81		=> "UserOrderId" ,
	99		=> "OrderAction" ,
	105		=> "ProductType" ,
	106		=> "MessageId" ,
	110		=> "AcceptAnonymous" ,
	111		=> "NumberOfMessages" ,
	112		=> "TotalNumMessages" ,
	113		=> "LastMessage" ,
	114		=> "LastSale" ,
	115		=> "BoardLot" ,
	119		=> "FaceValue" ,
	120		=> "OpeningTime" ,
	129		=> "Anonymous" ,
	150		=> "DisplayVolume" ,
	156		=> "OrderStatus" ,
	159		=> "MarketState" ,
	160		=> "MessageText" ,
	161		=> "StockState" ,
	162		=> "PrivateBusinessAction" ,
	163		=> "PrivateConfirmationType" ,
	166		=> "SellParticipation" ,
	167		=> "BuyParticipation" ,
	171		=> "CUSIP" ,
	172		=> "ProgramTrade" ,
	173		=> "Comment" ,
	177		=> "SymbolFullName" ,
	178		=> "PriorityTimeStamp" ,
	179		=> "BidPrice" ,
	180		=> "AskPrice" ,
	181		=> "PrivateBrokerNumber" ,
	182		=> "PrivateCFOdOrderNumber" ,
	183		=> "TradeCorrection" ,
	184		=> "RTAutofill" ,
	189		=> "SpreadGoal" ,
	191		=> "CalculatedOpeningPrice" ,
	192		=> "OrderKey" ,
	194		=> "MBX-PartNumber" ,
	195		=> "MBX-TotalParts" ,
	196		=> "PublicPrice" ,
	197		=> "MarketSide" ,
	199		=> "SpecialistName" ,
	211		=> "WashTrade" ,
	212		=> "AskSize" ,
	213		=> "BidSize" ,
	214		=> "PrivateOrderNumber" ,
	220		=> "TradeNumber" ,
	226		=> "TotalVolume" ,
	227		=> "PrivateNewOrderNumber" ,
	242		=> "FreezeLimit" ,
	247		=> "ExchangeId" ,
	251		=> "PriceType" ,
	255		=> "ResponsibleRTType" ,
	264		=> "TradeTimeStamp" ,
	265		=> "Exchange-UserId" ,
	268		=> "WarningLimit" ,
	274		=> "OpeningTrade" ,
	282		=> "StockGroup" ,
	283		=> "Market" ,
	284		=> "MGF-Setting" ,
	291		=> "ReferencePrice" ,
	311		=> "GatewayId" ,
	312		=> "SpecialistPhoneNumber" ,
	317		=> "BulletinIndicator" ,
	325		=> "RegulationId" ,
	380		=> "Exchange-Admin" ,
	390		=> "CrossType" ,
	490		=> "BlindOffsetAccepted" ,
	491		=> "CCP" ,
	492		=> "ImbalanceSide" ,
	493		=> "ImbalanceVolume" ,
	494		=> "MOC" ,
	496		=> "MOCEligible" ,
	499		=> "CPA" ,
	500		=> "PME" ,
	503		=> "ByPass" ,
	505		=> "NCIB" ,
	506		=> "OrigTradeID" ,
	508		=> "UndisclTradedVol" ,
	511		=> "SOROrderID1" ,
	512		=> "SOROrderID2" ,
	554		=> "ListingMkt" ,
	581		=> "TotalNumOpenOrders" ,
	582		=> "TotalNumStockGroups" ,
	583		=> "TotalNumSymbols" ,
	584		=> "TradingTierID" ,
	586		=> "NoTradeFeat" ,
	587		=> "NoTradeKey" ,
	588		=> "NoTradeOrderNum" ,
	589		=> "NoTradePrice" ,
	590		=> "NoTradeVol" ,
	591		=> "ExecInst" ,
	592		=> "BuyParticipationVolume" ,
	593		=> "RemainingBuyParticipationVolume" ,
	594		=> "RemainingSellParticipationVolume" ,
	595		=> "SellParticipationVolume" ,
	596		=> "HandlInst" ,
	597		=> "PegType" ,
	598		=> "MinQty" ,
	601		=> "QuoteID" ,
	602		=> "TSXATSTimestamp" ,
	603		=> "TSXAL1Timestamp" ,
	604		=> "Undisplayed" ,
	605		=> "AcceptUndisplayed" ,
	606		=> "IcebergRefresh" ,
	609		=> "ShortMarkingExempt" ,
	613		=> "SeekDarkLiquidity" ,
	614		=> "SelfTrade" ,
	615		=> "MatchingPriority" ,
	616		=> "ReasonCode" ,
	631		=> "ImbalanceReferencePrice" ,
	633		=> "Speedbump" ,
	634		=> "BuySpeedbump" ,
	635		=> "SellSpeedbump" , 
	640		=> "OrderQty" ,
	643		=> "LongLife" ,
	644		=> "AcceptLongLife" ,
	655		=> "POComment" ,
	657		=> "MarketID" ,
	658		=> "Multiplier" ,
	659		=> "NLSP" , 
	660		=> "PriceBandLimit" ,
    661		=> "PriceBandPercentage" ,
    662		=> "PriceBandOverrideCode" ,
    663		=> "PriceBandType" ,
    665		=> "TestSymbol" ,
    666		=> "OpeningMultiplier" ,
	669		=> "PegOffsetValue" ,
	670		=> "PrivateBypass" ,
	671		=> "AuctionRT" ,
	674		=> "SecondarySpecialistName" ,
	675		=> "SecondarySpecialistPhoneNumber" ,
	676		=> "SecondaryUserID" ,
	677		=> "SecondarySpreadGoal" ,
	678		=> "SecondaryTimeAtNBBO" ,
	679		=> "SecondaryTOBSize" ,
	680		=> "SecondaryBuyParticipation" ,
	681		=> "SecondarySellParticipation" ,
	682		=> "PrimaryMGFVol" ,
	683		=> "SecondaryMGFVol" ,
	684		=> "IsMidOnly"
);

# Add synthetic tags.  (Can't think of a better way)
# -------------------
$tagMap{ 9990 } = "DispTimeStamp";
$tagMap{ 9991 } = "Date";
$tagMap{ 9992 } = "CFOdUserOrderId";
$tagMap{ 9994 } = "ActPsv";


# Fields which may show up indexed.
# ---------------------------------
my @idxTags = ( 
    1 , 
    2 ,
    25 ,
    30 ,
    39 ,
    40 ,
    41 ,
    62 ,
    70 ,
    71 ,
    72 ,
    75 ,
    81 ,
    129 ,
    150 ,
    162 ,
    172 ,
    178 ,
    181 ,
    184 ,
    192 ,
    211 ,
    214 ,
    264 ,
    274 ,
    283 ,
    311 ,
    325 ,
    380 ,
    494 ,
    503 ,
    505 ,
    508 ,
    511 ,
    512 ,
    586 ,
    587 ,
    591 ,
    594 ,
    595 ,
    596 ,
    597 ,
    598 ,
    604 ,
    609 ,
	613 ,
    615 ,
	633 ,
    643 , 
	655 ,
	670
);

my %idxTagMap = (
    41    => 20 ,
    192   => 20
);


foreach my $tag ( @idxTags ) {
	my $maxIdx = $idxTagMap{ $tag };
	$maxIdx = 1 if !$maxIdx;
	foreach my $idx ( 0 .. $maxIdx ) {
		$tagMap{ "$tag.$idx" } = $tagMap{ $tag } . ".$idx"
	}
}

our %revTagMap = map { $tagMap{ $_ } => $_ } keys %tagMap;

my %TSXAcctTypeMap = (
	NC	=> "Non-client" ,
	CL	=> "Client" ,
	ST	=> "Equities specialist" ,
	IN	=> "Inventory" ,
	MP	=> "ME pro order" ,
	OF	=> "Options firm account" ,
	OT	=> "Options market maker"
);

my %TSXRegIdMap = (
	IA	=> "Insider Account" ,
	NA	=> "Not Applicable" ,
	SS	=> "Significant Shareholder"
);

my %toMktMap = map { $_ => 1 } qw ( D F G );

sub addTag {
	my ( $tag , $idx ) = @_;
	
	my $numTag = ( reverse sort keys %tagMap )[ 0 ] + 1;
	$tagMap{ $numTag } = $tag;
	$revTagMap{ $tag } = $numTag;
	
	if ( defined $idx ) {
		foreach my $idx ( 0 .. 1 ) {
			$tagMap{ "$numTag.$idx" } = "$tag.$idx";
			$revTagMap{ "$tag.$idx" } = "$numTag.$idx";
		}
	}
}

sub new {
	my $class = shift;
	
	my ( $tag , $val ) = @_;

	my $timeStamp;
	if ( $tag == 56 || $tag == 57 ) {
		( $timeStamp = $val ) =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$4:$5:$6.$7/;
	}

	my $idx;
	( $tag , $idx ) = split ( /\./ , $tag );

	my $self = {
		tag			=> $tag ,
		idx			=> $idx , 
		val			=> $val ,
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

	return "[$self->{tag}"
			. ( $self->{idx} ? ".$self->{idx}" : "" )
			. "]"
			. $tagMap{ $self->{tag} };
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
	
	my $str = ( $self->{pfx} ? "[$self->{pfx}]\n" : "" );
	$str .= $self->desc;
	if ( defined $self->{val} ) {
		$str .= " = " . $self->{val};
	}
	
	return $str;
}

1;