#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use FIXFld;

@ARGV = map { glob ( $_ ) } @ARGV;

my %revTagMap = map { $FIXFld::tagMap{ $_ } => $_ } %FIXFld::tagMap;

my %exDestMap = (
	'A'		=> 'ALE' ,
	'S'		=> 'TMXS' ,
	'T'		=> 'TSX' ,
	'X'		=> 'CDX'
);

my @months = qw ( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my $i = 1;
my %monthMap = map { $_ => $i++ } @months;

sub dateToStr {
	my ( $date ) = @_;
	if ( $date =~ /^(\d{2})\/(\d{2})\/(\d{4})$/ ) {
		my ( $mm , $dd , $yyyy ) = ( $1 , $2 , $3 );
		return "${yyyy}${mm}${dd}";
	}
	elsif ( $date =~ /^(\d{2})-(\S+)-(\d{4})$/ ) {
		my ( $dd , $mmm , $yyyy ) = ( $1 , $2 , $3 );
		my $mm = sprintf ( "%02d" , $monthMap{ $mmm } );
		return $date if !$mm;
		return "${yyyy}${mm}${dd}";
	}
	else {
		return $date;
	}
}

sub dateTimeToStr {
	my ( $dateTime ) = @_;
	my ( $date , $time , $ampm ) = split ( /\s/ , $dateTime );
	my ( $hh , $mm , $ss ) = split ( /:/ , $time );
	$hh += 12 if ( $ampm eq 'PM' && $hh != 12 );
	return ( $date , sprintf ( "%02d:%02d:%02d" , $hh , $mm , $ss ) );
}


# 'BUY'	Symbol	Traded Vol	Price	Trade Number	Trade Date	Trade Time	Buy Broker	Buy Trader	Order No	Buy Order Date	Order Book	Sell Broker	Buy Anonymous	Sell Anonymous	Action Source	Order Original Vol	Acct ID	Short Marker	Avg Price	CIOrdID	CumQty	ExecTransType	ExecType	LeavesQty	LastPx	LastShares	NoContraBrokers	OrderID	OrderQty	OrdStatus	OrdType	SenderCompid	ShortMarkingExempt	Side	TSXAccountType	TSXActionSource	TSXAnonymous	TSXBrokerNumber	TSXByPass	TSXExchangeAdmin	Status

# 'SELL'	Symbol	Traded Vol	Price	Trade Number	Trade Date	Trade Time	Sell Broker	Sell Trader	Order No	Sell Order Date	Order Book	Sell Broker_1	Buy Anonymous	Sell Anonymous	Action Source	Order Original Vol	Acct ID	Short Marker	Avg Price	CIOrdID	CumQty	ExecTransType	ExecType	LeavesQty	LastPx	LastShares	NoContraBrokers	OrderID	OrderQty	OrdStatus	OrdType	SenderCompid	ShortMarkingExempt	Side	TSXAccountType	TSXActionSource	TSXAnonymous	TSXBrokerNumber	TSXByPass	TSXExchangeAdmin	Status

my $delim = "";
#	$delim = "|";

my $execID = 0;

while ( <> ) {
	chomp;
	s/["']//g;
	
	s/\s*,\s*/,/g;	# --- strip leading and trailing spaces ---
	
	my ( undef , $sym , $vol , $price , $trdNo , $execDate , $execTime , $brkr , $trdrID , $orderNo , $orderDate , $orderBook ,
			$contraBrkr , $buyAnon , $sellAnon , $actionSrc , $origOrderVol , $acctId , $short , $avgPx ,
			$clOrdID , $cumQty , $execTransType , $execType , $lvsQty , $lastPx , $lastShares , $numContraBrks ,
			$orderID , $orderQty , $orderStatus , $orderType , $senderCompID , $sme , $side , $tsxAcctType , $tsxActionSrc ,
			$tsxAnon , $tsxBrkrNo , $tsxBypass , $tsxExchAdmin , $status ) 
		= split ( /,/ );

	next if ( $vol !~ /^\d+$/ );
	
	$execID++;
	
	$price = sprintf ( "%.5f" , $price );
	$avgPx = sprintf ( "%.5f" , $avgPx );
	$lastPx = sprintf ( "%.5f" , $lastPx );
	
	$brkr += 0;			# --- strip leading zeros ---
	$contraBrkr += 0;
	$tsxBrkrNo += 0;
	
	my $contraAnon = ( $side == 1 ? $sellAnon : $buyAnon );
	if ( $contraAnon eq 'Y' ) {
		$contraBrkr = 1;
	}
	
	my $dateStr = dateToStr ( $orderDate );
	my $bs = ( $side == 1 ? 'B' : 'S' );
	my $orderID = sprintf ( "${bs}${dateStr}%09d" , $orderNo );
		
	my ( $execDate , $execTime ) = dateTimeToStr ( $execTime );
	$execDate = dateToStr ( $execDate );
	$execTime = "${execDate}-${execTime}.000";
	
	$tsxExchAdmin =~ s/\s//g;
	
	my $exDest = $exDestMap{ substr ( $tsxExchAdmin , 0 , 1 ) };
	
	my @fldMap = ( 
		BeginString			=> "FIX.4.2" ,
		BodyLength			=> 123 ,
		
		MsgType				=> 8 , 		# --- Execution Report ---
		MsgSeqNum			=> $execID ,	# --- synthetic sequence num, same as ExecID ---
		SendingTime			=> $execTime ,
		SenderCompID		=> "TMXPRD2" ,
		SenderSubID			=> "00000011" ,
		Account				=> $acctId ,
		AvgPx				=> $avgPx ,
		ClOrdID				=> $clOrdID ,
		CumQty				=> $cumQty ,
		ExecID				=> $execID ,	# --- synthetic ExecID ---
		ExecTransType		=> 0 ,			# --- New ---
		OrdStatus			=> $orderStatus ,
		ExecType			=> $execType ,
		LastPx				=> $lastPx ,
		LastShares			=> $lastShares ,
		OrderID				=> $orderID ,
		OrderQty			=> $orderQty ,
		OrdType				=> $orderType ,
		Price				=> $price ,
		Side				=> $side ,
		Symbol				=> $sym ,
		TransactTime		=> $execTime ,
		LeavesQty			=> $lvsQty ,
		ContraBroker		=> $contraBrkr ,
		TSXUserID			=> $trdrID ,
		TSXAccountType		=> $tsxAcctType ,
		TSXActionSource		=> $tsxActionSrc ,
		TSXBrokerNumber		=> $tsxBrkrNo ,
		TSXExchangeAdmin	=> $tsxExchAdmin ,
		ExDestination		=> $exDest ,
		
		CheckSum			=> 123
	);
	
	my @fixFlds;
	for ( my $i = 0 ; $i < scalar @fldMap / 2 ; $i++ ) {
		my $fldName = $fldMap[ $i * 2 ];
		my $fldVal = $fldMap[ ( $i * 2 ) + 1 ];
		if ( $fldVal ne '' ) {
			push @fixFlds , [ $revTagMap{ $fldName } , $fldVal ];
		}
	}

	print join ( $delim , map { "$$_[ 0 ]=$$_[ 1 ]" } @fixFlds ) , "$delim\n";
}	