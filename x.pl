#!/usr/bin/env perl

use strict;
use Getopt::Long;
use File::Basename;
my $scriptName = basename $0;

use Data::Dumper;

use Util;
use Quote;
use STAMP::STAMPStream;

my $recordSep = $/;
# my $recordSep = chr ( 001 );

my %quoteBySym = ();
my @sides = qw ( BID ASK );
	
my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => 1 , RecordSep => $recordSep );

print",,BID,,,,ASK,,,";
print "Time,Event";
print ",Where,TMXQuote,TMXVol,AwayVol" x 2;
print "\n";

while ( my $msg = $stream->next ) {

#	Look only for quote messages.
#	-----------------------------
	next if !( $msg->isa ( "STAMP::STAMPQuoteMsg" ) );

	my $sym = $msg->getAttr ( "Symbol" );
	if ( !exists $quoteBySym{ $sym } ) {
		$quoteBySym{ $sym } = new Quote;
	}
	my $quote = $quoteBySym{ $sym };
	$quote->add ( $msg->BBO () , $msg->BBOQty () , $msg->isLocal () );
	
	printf "%s,%s" , $msg->timeStamp () , ( $msg->isLocal () ? "TBBO" : "ABBO" );
	
	foreach my $idx ( 0 .. 1 ) {
		my $lQuote = $quote->{LBBO}[ $idx ];
		my $lVol = $quote->{Vol}[ $idx ];
		my $aQuote = $quote->{ABBO}[ $idx ];
		my $lBetter = Util::isBetterPrice ( $lQuote , $aQuote , $sides[ $idx ] );
		printf ",%s,%.2f,%d,%.2f" , 
				( $lBetter > 0 ? "TMX" : ( $lBetter == 0 ? "TMX_AWAY" : "AWAY" ) ) ,
				$lQuote , $lVol , $aQuote
	}
	print "\n";
}
