#!c:/perl/bin/perl

use strict;

use Data::Dumper;

use STAMP::STAMPStream;
use STAMP::STAMPMsg;
use Quote;

sub accumKillMsg {
	my ( $symInfo , $killMsg ) = @_;

	my $po = $killMsg->getAttr ( "BrokerNumber" );
	$po = $killMsg->getAttr ( "PrivateBrokerNumber" ) if !$po;
	
	my $msgKey = join ( "," , $po , 
							$killMsg->getAttr ( "UserId" ) ,
							$killMsg->getAttr ( "BusinessAction" ) ,
							$killMsg->getAttr ( "Volume" ) ,
							$killMsg->getAttr ( "Price" )
						);
	
	$symInfo->{ killMsgs } = {} if !defined $symInfo->{ killMsgs };
	
	my $msgMap = $symInfo->{ killMsgs }{ $msgKey };
	if ( !defined $msgMap ) {
		$msgMap = $symInfo->{ killMsgs }{ $msgKey } = {};
		$msgMap->{ ClOrdID } = $killMsg->getAttr ( "UserOrderId" );	# --- cache just the first ClOrdID ---
		$msgMap->{ StartTimeStamp } = $killMsg->timeStamp;
	}
	$msgMap->{ EndTimeStamp } = $killMsg->timeStamp;
	$msgMap->{ Count }++;
}

sub dumpKills {
	my ( $symInfo ) = @_;
	
#	--- Dump most recent Quote/LSP msg here ---


	foreach my $msgKey ( sort { 
							$symInfo->{ killMsgs }{ $a }{ StartTimeStamp } cmp $symInfo->{ killMsgs }{ $b }{ StartTimeStamp } 
						} keys %{ $symInfo->{ killMsgs } } ) {
		my $msgMap = $symInfo->{ killMsgs }{ $msgKey };
		print join ( "," , 
						$symInfo->{ Sym } ,
						$msgMap->{ StartTimeStamp } ,
						$msgMap->{ EndTimeStamp } ,
						$msgMap->{ Count } ,
						$msgKey ,
						$msgMap->{ ClOrdID } ,
						$symInfo->{ Quote }{ Source } ,
						@{ $symInfo->{ Quote }{ Quote }{ NBBO } } ,
						$symInfo->{ Quote }{ Time } ,
						$symInfo->{ NLSP }{ Source } ,
						$symInfo->{ NLSP }{ Price } ,
						$symInfo->{ NLSP }{ Time }
					) , "\n";
	}

	$symInfo->{ killMsgs } = undef;
}

sub applySTAMPMsg {
	my ( $symInfo , $msg ) = @_;
	
	if ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
	if ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {

#		Only orders killed due to Marketplace Thresholds...
#		---------------------------------------------------
		return if !( $msg->isKilled () && $msg->getAttr ( "ReasonCode" ) == 25 );
		
		accumKillMsg ( $symInfo , $msg );
	}
	else {
		if ( defined $symInfo->{ killMsgs } ) {
			dumpKills ( $symInfo );
		}
	
		if ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
			$symInfo->{NLSP} = {
									Price	=> $msg->getAttr ( "LastSale" ) ,
									Source	=> "TRADE" ,
									Time	=> $msg->timeStamp
								};
		}

		elsif ( $msg->isa ( "STAMP::STAMPSymStatusMsg" ) ) {
			$symInfo->{NLSP} = {
									Price	=> $msg->getAttr ( "LastSale" ) ,
									Source	=> "SYM_STATUS" ,
									Time	=> $msg->timeStamp
								};
		}
		
		elsif ( $msg->isa ( "STAMP::STAMPNLSPMsg" ) ) {
			$symInfo->{NLSP} = {
									Price	=> $msg->getAttr ( "NLSP" ) ,
									Source	=> "ALSP" ,
									Time	=> $msg->timeStamp
								};
		}
		
		elsif ( $msg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
			$symInfo->{Quote}{ Quote }->add ( $msg->BBO , $msg->BBOQty , $msg->isLocal );
			$symInfo->{Quote}{ Source } = ( $msg->isLocal ? "LOCAL" : "AWAY" );
			$symInfo->{Quote}{ Time } = $msg->timeStamp;
		}
	}
}

print "Sym,FirstTime,LastTime,Count,PO,TraderID,Side,Quantity,Price,FirstClOrdID,NBBOSource,NBB,NBO,NBBOTime,NLSPSource,NLSP,NLSPTime\n";

my %symInfoMap = ();
#	{
#		symbol => {
#			Symbol ,
#			Quote object ,
#			NLSP ,
#			QuoteNLSPUpdateTime ,
#			killMsgs struct
#		}
#	}

while ( <> ) {
	chomp;
	my $msg = STAMP::STAMPMsg::newSTAMPMsg ( $_ );
	print STDERR "$....\n" if !( $. % 1000000 );
	
	next if !$msg;	
	next if ( !( $msg->isa ( "STAMP::STAMPTradeMsg" ) 
				|| $msg->isa ( "STAMP::STAMPNLSPMsg" ) 
				|| $msg->isa ( "STAMP::STAMPSymStatusMsg" )
				|| $msg->isa ( "STAMP::STAMPQuoteMsg" ) 
				|| $msg->isa ( "STAMP::STAMPOrderMsg" ) )
			);
			
	my $sym = $msg->getAttr ( "Symbol" );
	next if !$sym;
 
	if ( !exists $symInfoMap{ $sym } ) {
		$symInfoMap{ $sym } = {
			Sym => $sym ,
			NLSP => undef ,
			Quote => {
						Quote	=> new Quote ,
						Time	=> undef
					} ,
			KillMsgs => undef
		};
	}
	my $symInfo = $symInfoMap{ $sym };
	
	applySTAMPMsg ( $symInfo , $msg );
}