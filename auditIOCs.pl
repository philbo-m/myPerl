#!c:/perl/bin/perl

use strict;

use Data::Dumper;

use STAMP::STAMPStream;
use Quote;

my %quoteBySym;

my $recordSep = $/;
# my $recordSep = chr ( 001 );

my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => 0 , RecordSep => $recordSep );
while ( my $msg = $stream->next ) {
	if ( $msg->isa ( "STAMP::STAMPQuoteMsg" ) ) {
		my $sym = $msg->getAttr ( "Symbol" );
		if ( !exists $quoteBySym{ $sym } ) {
			$quoteBySym{ $sym } = new Quote;
		}
		my $quote = $quoteBySym{ $sym };
		$quote->add ( $msg->BBO () , $msg->BBOQty () , $msg->isLocal () );
	}
	
	elsif ( $msg->isa ( "STAMP::STAMPOrderMsg" ) ) {
		next if $msg->getAttr ( "ConfirmationType" ) ne 'Killed';
		next if $msg->getAttr ( "OrderDuration" ) ne 'IOC';
#		next if $msg->getAttr ( "SeekDarkLiquidity" );
#		print Dumper ( $msg ) , "\n";
		
		my $sym = $msg->getAttr ( "Symbol" );
		my $quote = $quoteBySym{ $sym };
		
		my $price = $msg->getAttr ( "PublicPrice" );
		my $side = $msg->getAttr ( "BusinessAction" );
		my $otherSide = ( $side eq 'Buy' ? 'ASK' : 'BID' );
		
		my $reason;
		my $tbbo = $quote->getPrice ( $otherSide , 'LBBO' );
		my $abbo = $quote->getPrice ( $otherSide , 'ABBO' );
		my $nbbo = $quote->getPrice ( $otherSide , 'NBBO' );
		
#		print "[$price] vs [$otherSide] TBBO [$tbbo] ABBO [$abbo] NBBO [$nbbo]...\n";
		if ( Util::isBetterPrice ( $price , $nbbo , $otherSide ) < 0 ) {	# --- Order price is inside the NBBO ---
			$reason = 'No liquidity';
		}
		elsif ( Util::isBetterPrice ( $price , $abbo , $otherSide ) >= 0 ) {	# --- Order price is better than the ABBO... 
			my $tbboBetterThanAbbo = Util::isBetterPrice ( $tbbo , $abbo , $otherSide );
			if ( $tbboBetterThanAbbo >= 0 ) {	# --- ABBO is inside the TBBO ---
				$reason = 'OPR Cancel';
			}
			else {	# --- TBBO is at, or inside, the ABBO ---
				$reason = 'Ambiguous';
			}
		}
		else {
			if ( Util::isBetterPrice ( $price , $tbbo , $otherSide ) >= 0 ) {	# --- Order price is equal to or better than the TBBO ---
				$reason = 'Exhausted liquidity';
			}
			else {	# --- SHOULD NEVER HAPPEN ---
				$reason = '?????';
			}
		}
		
		print $msg->dump () , " : " , $quote->dump () , " : $reason\n";
	}
}
