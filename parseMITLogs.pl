#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Data::Dumper;

use FIXMsg;
use Util;

# -----------------------------------------------------------
# Return 1 if the specified maps share any keys; 0 otherwise.
# -----------------------------------------------------------
sub doMapsIntersect {
	my ( $map1 , $map2 ) = @_;
	
	foreach my $key ( keys %$map1 ) {
		return 1 if exists $$map2{ $key };
	}
	return 0;
}

sub mkFldMap {
	my ( $rec , $delim ) = @_;
	my $fldIdx = 0;
	my %fldMap = map { $_ => $fldIdx++ } split ( $delim , $rec );
	
	return \%fldMap;
}

sub getFld { 
	my ( $fldList , $fldName , $fldMap ) = @_;
	return $$fldList[ $$fldMap{ $fldName } ];
}


sub mkOrderKey {
	my ( $order , $internal , $overrideMap ) = @_;
	$overrideMap = {} if !$overrideMap;
	my @flds = qw ( TSXUserID Sym Side );	
	if ( $internal ) {
		push @flds , "ClOrdID";
	}

	return join ( "," , map { exists $$overrideMap{ $_ } ? $$overrideMap{ $_ } : $$order{ $_ } } @flds );
}

sub dumpOrder {
	my ( $order ) = @_;
	return "[$order->{ TimeStamp }] : [" . join ( "] [" , map { "$_=$order->{ $_ }" } grep { $_ ne "TimeStamp" } sort keys %$order ) . "]";
}

# Need to keep track of:
# - Overall orders in chronological sequence - to get earliest order
# - Orders keyed by ClOrdID - to apply executions
# - Orders keyed by TSXUserID/Side/Sym - to associate with Mkt side orders
# ---------------------------------------------------------------------
sub addOrder {
	my ( $orderMap , $order ) = @_;
	
	my $orderExtKey = mkOrderKey ( $order , 0 );
	my $orderIntKey = mkOrderKey ( $order , 1 );
	
	push @{ $$orderMap{ OrdersByExtKey }{ $orderExtKey } } , $order; 	# --- List of all orders matching sym/side/msgType
	push @{ $$orderMap{ OrderIntKeyList } } , $orderIntKey;			# --- Sequence of all internal keys
	$$orderMap{ OrderByIntKey }{ $orderIntKey } = $order;			# --- Order repository, keyed by sym/side/ClOrdID
}

sub orderCount {
	my ( $orderMap ) = @_;
	
	return scalar @{ $$orderMap{ OrderIntKeyList } };
}

sub findOrderByIntKey {
	my ( $orderMap , $orderIntKey ) = @_;
	return $$orderMap{ OrderByIntKey }{ $orderIntKey };
}

sub findOrderListByExtKey {
	my ( $orderMap , $orderExtKey ) = @_;
	return $$orderMap{ OrdersByExtKey }{ $orderExtKey };
}

sub sortOrderLists {
	my ( $orderMap ) = @_;

	foreach my $orderExtKey ( keys %{ $$orderMap{ OrdersByExtKey } } ) {
		my $orderList = $$orderMap{ OrdersByExtKey }{ $orderExtKey };
		my @sortedList = sort { 
				$$a{ TimeStamp } cmp $$b{ TimeStamp } 
			} @$orderList;
		$$orderMap{ OrdersByExtKey }{ $orderExtKey } = \@sortedList;
	}
}

sub getFirstOrderByExtKey {
	my ( $orderMap , $orderExtKey ) = @_;
	
	return undef if ( !exists $$orderMap{ OrdersByExtKey }{ $orderExtKey } 
						|| !scalar @{ $$orderMap{ OrdersByExtKey }{ $orderExtKey } }
					);
	
	return $$orderMap{ OrdersByExtKey }{ $orderExtKey }[ 0 ];
}

sub popEarliestOrder {
	my ( $orderMap ) = @_;
	my $order;
	if ( scalar @{ $$orderMap{ OrderIntKeyList } } ) {
		my $intOrderKey = $$orderMap{ OrderIntKeyList }[ 0 ];
		$order = removeOrder ( $orderMap , $intOrderKey );
	}
	
	return $order;
}

sub removeOrder {
	my ( $orderMap , $intOrderKey , $removeReason ) = @_;
	
	my $order = delete $$orderMap{ OrderByIntKey }{ $intOrderKey };
	if ( $removeReason ) {
		print STDERR "Removing order : " , dumpOrder ( $order ) , " : $removeReason\n";
	}
	
	my $extOrderKey = mkOrderKey ( $order , 0 );
	
	my $idx = 0;
	foreach ( @{ $$orderMap{ OrderIntKeyList } } ) {
		last if ( $_ eq $intOrderKey );
		$idx++;
	}
	splice ( @{ $$orderMap{ OrderIntKeyList } } , $idx , 1 );

	$idx = 0;
	foreach ( @{ $$orderMap{ OrdersByExtKey }{ $extOrderKey } } ) {
		last if ( $_ eq $order );
		$idx++;
	}
	splice ( @{ $$orderMap{ OrdersByExtKey }{ $extOrderKey } } , $idx , 1 );
	
	return $order;
}

sub addRecentOrder {
	my ( $recentOrderMap , $order ) = @_;
	
	my $clOrdID = $$order{ ClOrdID };
	$$recentOrderMap{ Map }{ $clOrdID } = $order;
	push @{ $$recentOrderMap{ List } } , $clOrdID;
	
	if ( scalar @{ $$recentOrderMap{ List } } > 100 ) {
		$clOrdID = unshift @{ $$recentOrderMap{ List } };
		delete $$recentOrderMap{ Map }{ $clOrdID };
	}
}

sub findRecentOrder {
	my ( $recentOrderMap , $clOrdID ) = @_;
	
	my $order;
	if ( exists $$recentOrderMap{ Map }{ $clOrdID } ) {
		$order = $$recentOrderMap{ Map }{ $clOrdID };
	}
	return $order;
}
		
sub mktByCompID {
	my ( $mktCompID , $cltCompID ) = @_;
	
	my %tmxMktMap = (
		K	=> "TSX" ,
		L	=> "TSX" ,
		O	=> "TSX" ,
		P	=> "TSX" ,
		R	=> "TSXV" ,
		S	=> "TSXV" ,
		C	=> "ALPHA"
	);
	
	my $mkt;
	if ( $mktCompID =~ /OMEG/ ) {
		$mkt = "OMEGA";
	}
	elsif ( $mktCompID =~ /^NEO/ ) {
		$mkt = "AEQ";
	}
	elsif ( $mktCompID =~ /^CHIX/ ) {
		$mkt = "CHIX";
	}
	elsif ( $mktCompID =~ /^CX2/ ) {
		$mkt = "CX2";
	}	
	elsif ( $mktCompID =~ /\d+FIX\d+/ ) {
		$mkt = "CSE";
	}
	elsif ( $mktCompID =~ /^TMXPRD/ ) {
		( $mkt ) = ( $cltCompID =~ /^\d{4}(\S).+$/ );
		$mkt = $tmxMktMap{ $mkt };
	}
	
	return ( $mkt ? $mkt : "$mktCompID:UNKNOWN" );
}

my $delim = "";

my ( $mktFiles , $cltFiles );

GetOptions ( 
	'd=s'	=> \$delim ,
	'm=s'	=> \$mktFiles ,
	'c=s'	=> \$cltFiles
) or die;

local $| = 1;

my %childOrderMap = ();
my %recentOrderMap = ();

foreach my $mktFile ( split /,/ , $mktFiles ) {
	print STDERR "$mktFile...\n";
	open FILE , $mktFile or die "Cannot open $mktFile : $!";
		
	while ( <FILE> ) {
		chomp;
	
		if ( !( $. % 100000 ) ) {
			print STDERR $. , "...\n";
		}
		
	    my $msg = new FIXMsg ( delim => $delim );
		$msg->parse ( $_ );
				
		my $msgType = $msg->fldVal ( 'MsgType' );
		my $ts = $msg->fldVal ( 'TimeStamp' );
		my $trdrID = $msg->fldVal ( 'TSXUserID' );
		my $sym = $msg->fldVal ( 'Symbol' );
		my $side = $msg->fldVal ( 'Side' );
		my $qty = $msg->fldVal ( 'OrderQty' );
		my $clOrdID = $msg->fldVal ( 'ClOrdID' );
		
		if ( $msgType =~ /[DFG]/ ) { 	# --- new order/CFO/CXL ---

			my ( $cltCompID , $mktCompID ) = ( $msg->fldVal ( 'SenderCompID' ) , 
												$msg->fldVal ( 'TargetCompID' ) 
											);
			my $mkt = mktByCompID ( $mktCompID , $cltCompID );
			
#			print STDERR "$ts : Msg [$msgType] [$trdrID] [$sym] [$side] : [$clOrdID]\n";
			my $order = { 
					TimeStamp => $ts ,
					ClOrdID => $clOrdID , 
					Mkt => $mkt ,
					TSXUserID => $trdrID ,
					Sym => $sym ,
					Side => $side ,
					OrderQty => $qty ,
					MsgType => $msgType
				};

			addOrder ( \%childOrderMap , $order );
			addRecentOrder ( \%recentOrderMap , $order );
		}
		else {	# --- Exec ---
			
			my ( $mktCompID , $cltCompID ) = ( $msg->fldVal ( 'SenderCompID' ) , 
												$msg->fldVal ( 'TargetCompID' ) 
											);
			my $execType = $msg->fldVal ( 'ExecType' );
			my $orderIntKey = "$trdrID,$sym,$side,$clOrdID";
			
#			Find the order matching this Exec's ClOrdID.
#			--------------------------------------------
			my $order = findRecentOrder ( \%recentOrderMap , $clOrdID );
			if ( !$order ) {
				$order = findOrderByIntKey ( \%childOrderMap , $orderIntKey );
			}
			if ( !$order ) {
				print STDERR "$ts ; Exec msg [$execType] [$orderIntKey] found with no matching child order\n";
				next;
			}
#			print STDERR "$ts : Exec Msg [$execType] matching [$orderIntKey]...\n";

#			OrderIDMap will contain:
#			- NEW orders : the OrderID of the newly placed child order
#			- CXLs : the OrderID of the order being CXLed
#			- CFOs :
#			Skip this if it is a rejection.
#			----------------------------------------------------------
			if ( $execType ne '8' ) {
				my $orderID = $msg->fldVal ( 'OrderID' );
				if ( $orderID ) {
					$$order{ OrderIDMap }{ $orderID } = 1;
				}
				
				foreach ( qw ( TSXUserID OrderQty ) ) {
					my $val = $msg->fldVal ( $_ );
					$$order{ $_ } = $val if $val;
				}
			}

			$$order{ AckTimeStamp } = $ts if !$$order{ AckTimeStamp };		
		}
	}
	
	close FILE;
}

# Sort the child order lists by timestamp.
# ----------------------------------------
sortOrderLists ( \%childOrderMap );

my %cltOrderMap = ();
%recentOrderMap = ();

print "Time,CompID,TSXUserID,Sym,Side,Qty,MsgType,ClOrdID,MITClOrdID,NumChildRecs,NumFirstSpray,MinLatency,MaxLatency\n";

foreach my $cltFile ( split /,/ , $cltFiles ) {
	print STDERR "$cltFile...\n";
	open FILE , $cltFile or die "Cannot open $cltFile : $!";
	
	while ( <FILE> ) {
		chomp;
		
		if ( !( $. % 100000 ) ) {
			print STDERR $. , "...\n";
		}

	    my $msg = new FIXMsg ( delim => $delim );
		$msg->parse ( $_ );
		
		my $msgType = $msg->fldVal ( 'MsgType' );
		my $ts = $msg->fldVal ( 'TimeStamp' );
		my $clOrdID = $msg->fldVal ( 'ClOrdID' );
		my $origClOrdID = $msg->fldVal ( 'OrigClOrdID' );
		my $trdrID = $msg->fldVal ( 'TSXUserID' );
		my $sym = $msg->fldVal ( 'Symbol' );
		my $symSfx = $msg->fldVal ( 'SymbolSfx' );
		my $side = $msg->fldVal ( 'Side' );

		$sym .= ".$symSfx" if $symSfx;	
		$side = "5" if $side eq '6';	# --- convert SSE to SS ---
		$trdrID = "I" . $trdrID if $trdrID eq 'C18129';	# --- egregious hack for Instinet CXLs ---
		
		if ( $msgType =~ /[DFG]/ ) {	# --- New client order ---
		
#			print STDERR "$ts : Msg [$msgType] [$trdrID] [$sym] [$side] : [$clOrdID]\n";

			my $cltCompID = $msg->fldVal ( 'SenderCompID' );
			my $qty = $msg->fldVal ( 'OrderQty' );
			
			my $order = { 
					TimeStamp => $ts ,
					CompID => $cltCompID ,
					ClOrdID => $clOrdID ,
					OrigClOrdID => $origClOrdID ,
					MsgType => $msgType ,
					TSXUserID => $trdrID ,
					Sym => $sym ,
					Side => $side ,
					Qty => $qty
				};
				
			addOrder ( \%cltOrderMap , $order );
			addRecentOrder ( \%recentOrderMap , $order );
			
			if ( $msgType eq 'G' ) {

#				Find previous order and grab its SOR Order ID (will be used later to correlate 
#				Client CFOs with Child CXL/Rebooks).
#				------------------------------------------------------------------------------
				my $prevIntKey = mkOrderKey ( $order , 1 , { ClOrdID => $origClOrdID } );
				my $prevOrder = findOrderByIntKey ( \%cltOrderMap , $prevIntKey );
				if ( $prevOrder ) {
					$$order{ OrigTSXSOROrderID1 } = $$prevOrder{ TSXSOROrderID1 };
				}
				else {
					print STDERR "Prev order not found for CFO " , dumpOrder ( $order ) , "\n";
				}
			}
		}

		else {
		
			my $execType = $msg->fldVal ( 'ExecType' );
			my $orderIntKey = "$sym,$side,$clOrdID";

			my $order = findRecentOrder ( \%recentOrderMap , $clOrdID );
			if ( !$order ) {
				$order = findOrderByIntKey ( \%cltOrderMap , $orderIntKey );
			}
			if ( !$order ) {
				print STDERR "$ts : Msg [$msgType] [$execType] [$orderIntKey] : No matching order...\n";
				next;
			}
			
			my $orderMsgType = $$order{ MsgType };
			my $closeReason 
					= $execType eq '8' ? "REJECTION" : 
						$msgType eq '9' ? "ORDER CXL REJECT" :
						( $execType eq '4' && $orderMsgType =~ /^[DG]$/ ) ? "CXL OF NEW/CFO" :
						""
					;
					
			if ( $closeReason ) {
				my $orderTS = $$order{ TimeStamp };
				my $tsDiff = Util::tsDiff ( $orderTS , $ts );
				if ( $tsDiff < 100000 ) {	# --- heuristic to screen out COD-related order CXLs ---
#					print STDERR "Order " , dumpOrder ( $order ) , " CXLed : $closeReason\n";
					$$order{ CxlTimeStamp } = $ts;
					$$order{ CloseReason } = $closeReason;
#					removeOrder ( \%cltOrderMap ,  mkOrderKey ( $order , 1 ) , $closeReason );
				}
			}
						
			$$order{ AckTimeStamp } = $ts if !$$order{ AckTimeStamp };

			foreach ( qw ( OrderID ) ) {
				my $val = $msg->fldVal (  $_ );
				$$order{ $_ } = $val if $val;
			}
			foreach ( qw ( TSXSOROrderID1 TSXSOROrderID2 ) ) {
				my $val = $msg->fldVal ( $_ );
				$$order{ $_ }{ $val } = 1 if $val;
			}
		}
		
		if ( orderCount ( \%cltOrderMap ) > 10000000 ) {
			processEarliestOrder ( \%cltOrderMap , \%childOrderMap );
		}
	}

	close FILE;
}

# print STDERR "CLIENT ORDERS : \n" , Dumper ( \%cltOrderMap ) , "\n\n";

while ( orderCount ( \%cltOrderMap ) ) {
	processEarliestOrder ( \%cltOrderMap , \%childOrderMap );
}

# print STDERR "Done parsing msgs...\n";


sub processEarliestOrder {
	my ( $cltOrderMap , $childOrderMap ) = @_;
	
	my $cltOrder = popEarliestOrder ( $cltOrderMap );
	my $orderExtKey = mkOrderKey ( $cltOrder , 0 );
	my $nextCltOrder = getFirstOrderByExtKey ( $cltOrderMap , $orderExtKey );
	
	my $cltTS = $$cltOrder{ TimeStamp };
	my $cltAckTS = $$cltOrder{ AckTimeStamp };
	my $cltCompID = $$cltOrder{ CompID };
	my $msgType = $$cltOrder{ MsgType };
	my $qty = $$cltOrder{ Qty };
	my $sym = $$cltOrder{ Sym };
	my $side = $$cltOrder{ Side };
	my $trdrID = $$cltOrder{ TSXUserID };
	my $cltOrderID = $$cltOrder{ OrderID };
	my $cltClOrdID = $$cltOrder{ ClOrdID };
	my $cltSOROrdIDs = $$cltOrder{ TSXSOROrderID1 };

	my $nextCltTS = ( $nextCltOrder ? $$nextCltOrder{ TimeStamp } : undef );
	my $nextCltOrderID = ( $nextCltOrder ? $$nextCltOrder{ OrderID } : undef );
	my $timeToNextClt = ( $nextCltTS ? Util::tsDiff ( $cltTS , $nextCltTS ) : 999999999999 );
	
	print STDERR "Clt Order : " , dumpOrder ( $cltOrder ) , " SOR Order IDs [" , join ( "," , sort keys %{ $$cltOrder{ TSXSOROrderID1 } } ) , "]\n";
	if ( !$cltSOROrdIDs ) {
		print STDERR "No SOR Order IDs...\n";
#		next;
	}
	print STDERR "...next clt order : " , ( $nextCltOrder ? dumpOrder ( $nextCltOrder ) : "NONE" ) , "...\n";
	
	my $ordList = findOrderListByExtKey ( $childOrderMap , $orderExtKey );
	
	if ( !$ordList || !scalar @$ordList ) {
		print STDERR "No child orders for $cltTS : [$cltCompID] [$orderExtKey]...\n";
		next;
	}
	
	my $origCltSOROrdIDs;
	if ( $msgType eq 'G' ) {
		$origCltSOROrdIDs = $$cltOrder{ OrigTSXSOROrderID1 };
	}

	my @childOrderList = @$ordList;
#	print STDERR "Matching Child order list:\n" , join ( "\n" , map { dumpOrder ( $_ ) } @childOrderList ) , "\n";
	my %childMktMap = ();
	my $firstSpray = 1;
	my $numFirstSpray = 0;
	my ( $firstLatency , $lastLatency );
	my $maxAckTS;
	my @childRecs = ();
	
#	What orders to look for in the child order list?
#	If client order is NEW or CXL, then search by the Client OrderID (TSXSOROrderID1).
#	If client order is CFO, then the corresponding Child order might be:
#		- a CFO (if order is *not* marketable after the CFO)
#		- a CXL (1st half of CXL-rebook if order *is* marketable after the CFO).
#	----------------------------------------------------------------------------------
	my $useCltSOROrdIDs = ( $origCltSOROrdIDs ? undef : $cltSOROrdIDs );
	
	foreach my $childOrder ( @childOrderList ) {
		my $childTS = $$childOrder{ TimeStamp };
		my $childClOrdID = $$childOrder{ ClOrdID };
		my $childTrdrID = $$childOrder{ TSXUserID };
		my $childMsgType = $$childOrder{ MsgType };
		my $childOrderIDMap = $$childOrder{ OrderIDMap };
		
		print STDERR "...child order " , dumpOrder ( $childOrder ) , " OrderIDs [" , join ( "," , sort keys %$childOrderIDMap ) , "]...\n";
	
#		What would make us decide that a child order belonged to this client order, or not?
#		- More than 1 second (or whatever) ahead - NO and stop looking
#		- Earlier than client order somehow - NO
#		- Wrong type of order - NO
#		- Earlier than next client order - YES
# 		- OrderID matches the NEXT client order's SOROrdID - NO and stop looking
#		- OrderID matches the client order's SOROrdID (or, for CFOs, its original order's SOROrdID) - YES
#		- Less than 100 ms (or whatever) ahead of next order, and matches OrderQty - YES
#		-------------------------------------------------------------------------------------------------
		my $latency = Util::tsDiff ( $cltTS , $childTS );
		print STDERR "...latency [$latency]...\n";
		last if $latency > 1000000;
				
		if ( $latency <= 0 ) {
			print STDERR "...too early (must somehow belong to earlier clt order)...\n";
			removeOrder ( $childOrderMap , mkOrderKey ( $childOrder , 1 ) );
			next;
		}
		
		if ( ( $msgType eq 'G' && $childMsgType !~ /^[GX]$/ ) 
				|| ( $msgType ne 'G' && $msgType ne $childMsgType ) ) {
			print STDERR "...Clt order type does not match...\n";
			next;
		}

		if ( $latency < $timeToNextClt ) {
			print STDERR "...earlier than next clt order...\n";
		}
		
		else {
			if ( !scalar keys %$childOrderIDMap ) {
				print STDERR "...no OrderID map - assume belongs to this order...\n";
			}
			else {
			
	#			Figure out which SOR order ID set to use, if necessary.
	#			-------------------------------------------------------
				if ( !$useCltSOROrdIDs ) {
					foreach ( $origCltSOROrdIDs , $cltSOROrdIDs ) {
						if ( doMapsIntersect ( $_ , $childOrderIDMap ) ) {
							$useCltSOROrdIDs = $_;
							last;
						}
					}
				}
				
				if ( !$useCltSOROrdIDs || !doMapsIntersect ( $useCltSOROrdIDs , $childOrderIDMap ) ) {
					print STDERR "...Clt SOR OrderID(s) not found in child OrderID map...\n";
					next;
				}
			}
		}
		
		removeOrder ( $childOrderMap , mkOrderKey ( $childOrder , 1 ) );
		
		$firstLatency = $latency if !$firstLatency;
		
		my $mkt = $$childOrder{ Mkt };
		my $clOrdID = $$childOrder{ ClOrdID };
		my $childAckTS = $$childOrder{ AckTimeStamp };
		
		if ( $firstSpray ) {
			if ( exists $childMktMap{ $mkt } ) {
				print STDERR "......past first spray - seen mkt [$mkt] already...\n";
				$firstSpray = 0;	# --- already seen this child mkt -> this is the next spray ---
			}
			elsif ( $maxAckTS && $childTS gt $maxAckTS ) {
				print STDERR "......past first spray - prev child already ACKed...\n";
				$firstSpray = 0;	# --- Child order sent after some previous child order already ACKed - this is the next spray ---
			}
			else {
				$childMktMap{ $mkt } = 1;
				$maxAckTS = Util::max ( $maxAckTS , $childAckTS );
				$numFirstSpray++;
				if ( $childTS gt $cltAckTS ) {
#					print STDERR "$cltTS : [$cltCompID] [$orderKey]: acked [$cltAckTS]; child sent [$childTS]...\n";
				}									
			}
		}
		
		$lastLatency = $latency if $firstSpray;
		
		push @childRecs , "\t" . ( $firstSpray ? "*" : " " ) . " $childTS => $$childOrder{ Mkt } ==> $childAckTS ($clOrdID)";
	}
	print STDERR "CLT ORDER [$orderExtKey] [$qty] [$cltClOrdID] [$cltOrderID] [$firstLatency] [$lastLatency]:\n";
	print STDERR join ( "\n" , @childRecs ) , "\n";
	
	my $numChildRecs = scalar @childRecs;
	print "$cltTS,$cltCompID,$orderExtKey,$qty,$msgType,$cltClOrdID,$cltOrderID,$numChildRecs,$numFirstSpray,$firstLatency,$lastLatency,$$cltOrder{ CloseReason }\n";
}

print STDERR "Leftover mkt side orders:\n" , Dumper ( \%childOrderMap ) , "\n";
