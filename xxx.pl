#!c:/perl/bin/perl

use strict;

use STAMPFld;

sub getFld {
	my ( $rec , $fldMap , $fld ) = @_;

	return $$fldMap{ $fld } if exists $$fldMap{ $fld };
	
	my ( $key , $idx ) = split /\./ , $fld;
	my $numKey = $STAMPFld::revTagMap{ $key } . ( $idx eq '' ? "" : ".$idx" );	

	my $str = "\036$numKey=";
	my $val;
	my $pos = index ( $rec , $str );
	if ( $pos == -1 ) {
		$val = '';
	}
	else {
		my $len = index ( substr ( $rec , $pos + length ( $str ) ) , "\036" );
		$val = substr ( $rec , $pos + length ( $str ) , $len );
	}
	$$fldMap{ $fld } = $val;
	return $val;
	
#	$rec =~ /[^0-9]$fld=([[:print:]]+)/;
#	$$fldMap{ $fld } = $1;
#	return $1;
}	
	
my $rec;

my $ptrn = "[\036\034=]+";

our $busClassRE = "[^0-9]" . $STAMPFld::revTagMap{ "BusinessClass" } . "=([A-Za-z]+)";

my $rec = <>;
chomp $rec;
$rec = substr ( $rec , 1 );

print STDERR localtime . '' , "\n";
for ( 1 .. 1 ) {
	print STDERR "$_\n" if ( !( $_ % 100000 ) );
#	split ( /$ptrn/o , $rec );
	my %fldMap = split ( /$ptrn/o , $rec );
	next;
}
print STDERR localtime . '' , "\n";

for ( 1 .. 1000000 ) {
	print STDERR "$_\n" if ( !( $_ % 100000 ) );
	my %fldMap;
	foreach my $fld ( qw ( TimeStamp BusinessClass TimeStamp BusinessAction ) ) {
		my $val = getFld ( $rec , \%fldMap , $fld );
#		print STDERR "[$fld] = [" , getFld ( $rec , \%fldMap , $fld ) , "]\n";
	}
}
print STDERR localtime . '' , "\n";
exit;
for ( 1 .. 1000000 ) {
	print STDERR "$_\n" if ( !( $_ % 100000 ) );
	
	my ( $pos , $ppos ) = ( -1 , -1 );
#	my %fldMap;
	while ( ( $pos = index ( $rec , "\036" , $pos + 1 ) ) != -1 ) {
		if ( $ppos != -1 ) {
			my $eqIdx = index ( $rec , "=" , $ppos + 1 );
			my $x = substr ( $rec , $ppos + 1 , $eqIdx - $ppos - 1 );
			my $y = substr ( $rec , $eqIdx + 1 , $pos - $eqIdx - 1 );
#			$fldMap{ substr ( $rec , $ppos + 1 , $eqIdx - $ppos - 1 ) } = substr ( $rec , $eqIdx + 1 , $pos - $eqIdx - 1 );
		}
		$ppos = $pos;
	}
}
print STDERR localtime . '' , "\n";

exit;
	
for ( 1 .. 10000000 ) {
	print STDERR "$_\n" if ( !( $_ % 100000 ) );
		
	my ( $pos , $ppos ) = ( -1 , -1 );
#	my ( @flds , @idxs );
	my %fldMap;
	while ( ( $pos = index ( $_ , "\036" , $pos + 1 ) ) != -1 ) {
#		print "fld at idx [$pos]...\n";
#		next;
		if ( $ppos != -1 ) {
			my $eqIdx = index ( $_ , "=" , $ppos + 1 );
			$fldMap{ substr ( $_ , $ppos + 1 , $eqIdx - $ppos - 1 ) } = substr ( $_ , $eqIdx + 1 , $pos - $eqIdx - 1 );
#			push @flds , substr ( $_ , $ppos + 1 , $eqIdx - $ppos - 1 );
#			push @idxs , [ $eqIdx + 1 , $pos - $eqIdx - 1 ];
#			print "[$ppos] [$pos] [$eqIdx] [$flds[ $#flds] ] [$idxs" , substr ( $_ , $ppos + 1 , index ( $_ , "=" , $ppos + 1 ) - $ppos - 1 ) , "]\n";
		}
		$ppos = $pos;
	}
#	foreach my $key ( sort { $a <=> $b } keys %fldMap ) {
#		print "[$key] = [$fldMap{ $key }]\n";
#	}
#	for my $i ( 0 .. $#flds ) {
#		print "[$idxs[ $i ][ 0 ]] [$idxs[ $i ][ 1 ]] [$flds[ $i ]] [" , substr ( $_ , $idxs[ $i ][ 0 ] , $idxs[ $i ][ 1 ] ) , "]\n";
#	}
#	print "\n";

#	my @rec = $_;
#	split $ptrn;
#	split "=";
#	$rec = [ split /[\036\034=]+/o ];
	print STDERR "$_\n" if ( !( $_ % 100000 ) );
#	my @rec = /[\036\034=]+([^\036\034=]+)/g;
	
#	print "[" , join ( "] [" , @rec ) , "]\n";
}

__DATA__

use strict;
use Getopt::Long;
use Data::Dumper;
# use bigint;

use File::Basename;
use lib dirname $0;

use STAMP::STAMPStream;
use STAMP::STAMPMsg;
use StampFld;
use Quote;

sub tsToTime {
	my ( $ts ) = @_;	# --- HHMMSSnnnnnnnnn - only using milliseconds ---

	my @tp = ( $ts =~ /^(..)(..)(.....)/ );
	return ( ( ( $tp[ 0 ] * 60 ) + $tp[ 1 ] ) * 60 * 1000 ) + $tp[ 2 ];
}

sub timeToTS {
	my ( $time ) = @_;
	my ( $s , $ms ) = ( $time =~ /^(.+)(.{3})/ );
	my $hh = int ( $s / 3600 );
	my $mm = int ( ( $s % 3600 ) / 60 );
	my $ss = $s % 60;
	
	return sprintf ( "%02d%02d%02d%s" , $hh , $mm , $ss , $ms );
}


sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HHMMSSnnnnnnnnn ---
	return abs ( tsToTime ( $ts0 ) - tsToTime ( $ts1 ) );
}

sub tsAdd {
	my  ( $ts , $incr ) = @_;	# --- HHMMSSnnnnnnnnn , timeInMillis ---
	return timeToTS ( tsToTime ( $ts ) + $incr );
}

sub processQuote {
	my ( $msg , $sym , $quoteMap , $midPtMap ) = @_;

	my $quote = $$quoteMap{ $sym };
	if ( !$quote ) {
		$quote = new Quote;
		$$quoteMap{ $sym } = $quote;
	}
	$quote->add ( $msg->BBO , $msg->BBOQty , $msg->isLocal );

	if ( exists $$midPtMap{ $sym } ) {

		my $timeStamp = $msg->timeStamp;
		print join ( "," , $timeStamp ,
							"" ,
							$sym , 
							$quote->dump ,
							$msg->isLocal ? "LBBO" : "ABBO" , 
				) , "\n";
		
		my $midPtMsgMap = $$midPtMap{ $sym };
		my @uniqIds = keys %$midPtMsgMap;
		foreach my $uniqId ( @uniqIds ) {
			my $midPtMsg = $$midPtMsgMap{ $uniqId };
			if ( !$midPtMsg->isPeggedTradeable ( $quote ) ) {
				removeOrder ( $midPtMap , $sym , $uniqId , $midPtMsg , $quote , $timeStamp , "MID PT DARK NO LONGER TRADEABLE" );
			}
		}
	}
}

sub expireOrders {
	my ( $midPtMap , $sym , $quote , $timeStamp ) = @_;
	return if !exists $$midPtMap{ $sym };
	my @uniqIds = keys %{ $$midPtMap{ $sym } };
	my $fmtTimeStamp = STAMP::STAMPMsg::fmtTimeStamp ( $timeStamp );

	foreach my $uniqId ( @uniqIds ) {
		my $midPtMsg = $$midPtMap{ $sym }{ $uniqId };
		if ( $midPtMsg->getAttr ( "ExpiryTimeStamp" ) lt $timeStamp ) {
			removeOrder ( $midPtMap , $sym , $uniqId , $midPtMsg , $quote , $fmtTimeStamp , "MID PT DARK DISCARDED" );
		}
	}
}
	
sub removeOrder	{
	my ( $midPtMap , $sym , $uniqId , $order , $quote , $timeStamp , $reason ) = @_;
	$order->setAttr ( "ConfirmationType" , $reason );
	
	print join ( "," , $timeStamp ,
						"" ,
						$sym ,
						$quote->dump ,
						$order->dump
				) , "\n";
	delete $$midPtMap{ $sym }{ $uniqId };

	if ( !scalar keys %{ $$midPtMap{ $sym } } ) {
		delete $$midPtMap{ $sym };
	}
}

sub processOrder {
	my ( $msg , $sym , $lastOrderMap , $midPtMap , $quoteMap ) = @_;
	
	my $quote = $$quoteMap{ $sym };
	my $interval;

	my $lastMsg = $$lastOrderMap{ $sym };
	$$lastOrderMap{ $sym } = $msg;
	if ( $lastMsg ) {
		$interval = tsDiff ( $lastMsg->getAttr ( "TimeStamp" ) , $msg->getAttr ( "TimeStamp" ) ); # --- milliseconds ---
		$msg->setAttr ( "OrderGap" , $interval );
	}
		
	$quote = $$quoteMap{ $sym };
	
	if ( $msg->getAttr ( "ConfirmationType" ) eq 'NEW' && $msg->isPeggedTradeable ( $quote ) ) {
		$msg->setAttr ( "ConfirmationType" , "MID PT DARK TRADEABLE" );
		$msg->setAttr ( "ExpiryTimeStamp" , tsAdd ( $msg->getAttr ( "TimeStamp" ) , 5000 ) ); # --- three seconds to live ---
		$$midPtMap{ $sym }{ $msg->uniqId } = $msg;
	}
	if ( exists $$midPtMap{ $sym } ) {
		print join ( "," , $msg->timeStamp ,
							$msg->getAttr ( "OrderGap" ) ,
							$sym ,
							$quote->dump ,
							$msg->dump
					) , "\n";
	}						
}

sub processTrade {
	my ( $msg , $sym , $midPtMap , $quoteMap ) = @_;
	
	if ( exists $$midPtMap{ $sym } ) {
	
		my $quote = $$quoteMap{ $sym };
		my $timeStamp = $msg->timeStamp;
	
		print join ( "," , $timeStamp ,
							$msg->getAttr ( "OrderGap" ) ,
							$sym ,
							$quote->dump ,
							$msg->dump
					) , "\n";

		foreach ( 0 .. 1 ) {
			my $uniqId = $msg->uniqId ( $_ );
			if ( exists $$midPtMap{ $sym }{ $uniqId } ) {
				my $order = $$midPtMap{ $sym }{ $uniqId };
				$order->applyTrade ( $msg , $_ );
				if ( !$order->getAttr ( "RemainingVolume" ) ) {
					removeOrder ( $midPtMap , $sym , $uniqId , $order , $quote , $timeStamp , "MID PT DARK FILLED" );
				}
			}
		}
	}
}

my %quoteMap = ();
my @msgCache = ();
my %lastOrderMap = ();
my %midPtMap = ();

my $stream = new STAMP::STAMPStream ( file => "$ARGV[ 0 ]" );

print "Time,Gap,Symbol,ABB,ABO,CBBQ,CBOQ,CBB,CBO,NBB,NBO,Event,Side,Qty,Price,Attr,PO,TrdrID,OrderID,Attr,PO,TrdrID,OrderID\n";

my ( $q , $o , $t );
while ( my $msg = $stream->next ) {

	my $sym = $msg->getAttr ( "Symbol" );
	my $ts = $msg->timeStamp;
	
	if ( $msg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
		processQuote ( $msg , $sym , \%quoteMap , \%midPtMap );
		print STDERR join ( "," , $ts , "QUOTE" , $quoteMap{ $sym }->dump  , $msg->isLocal ? "LBBO" : "ABBO" ) , "\n";
	}
	else {
		print STDERR join ( "," , $ts , $msg->dump ) , "\n";
	}

	next;

#	Discard old orders first.
#	-------------------------
	my $timeStamp = $msg->getAttr ( "TimeStamp" );
	expireOrders ( \%midPtMap , $sym , $quoteMap{ $sym } , $timeStamp );
	
	if ( $msg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
		$q++;
		processQuote ( $msg , $sym , \%quoteMap , \%midPtMap );
	}
	elsif ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
		$o++;
		processOrder ( $msg , $sym , \%lastOrderMap , \%midPtMap , \%quoteMap );
	}
	elsif ( $msg->isa ( "STAMP::STAMPTradeMsg" ) ) {
		$t++;
		processTrade ( $msg , $sym , \%midPtMap , \%quoteMap );
	}
}
print STDERR "[$q] quotes; [$o] orders; [$t] trades\n";