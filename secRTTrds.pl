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
	
my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => 1 , RecordSep => $recordSep );

print "DATE,TIME,PO,TRDRID,RT_PO,RT_TRDRID,RT_AUTO,SYM,VOL,PRICE,HI_LO\n";

while ( my $msg = $stream->next ) {

#	Look only for trade messages.
#	-----------------------------
	next if !( $msg->isa ( "STAMP::STAMPTradeMsg" ) );

#	...that aren't corrections.
#	---------------------------
	next if $msg->getAttr ( "TradeCorrection" );
	
#	...and that involve a Secondary RT and are not wash trades.
#	-----------------------------------------------------------
	my ( $washTrade , $rtAutofill );
	my ( $rtSide , $secRTIdx ) = ( -1 , -1 );
	foreach my $idx ( 0 .. 1 ) {
		$washTrade = $msg->getAttr ( "WashTrade" , $idx ); # --- will be there on both sides if at all ---
		my $exchAdmin = $msg->getAttr ( "Exchange-Admin" , $idx );
		my $rtFlag = ( split // , $exchAdmin )[ 3 ];
		my $acctType = $msg->getAttr ( "AccountType" , $idx );
		if ( $acctType eq 'ST' && $rtFlag =~ /[YS]/ ) {	# --- this side is RT ---
			if ( $rtSide != -1 ) {	# --- but so is the other side ---
				$secRTIdx = -1;
				last;
			}
			$rtSide = $idx;
			if ( $rtFlag eq 'S' ) {
				$secRTIdx = $idx;
				$rtAutofill = $msg->getAttr ( "RTAutofill" , $idx );
			}
		}
	}
	
#	...and are Oddlot/MGF auto-fills against a *NON-RT*.
#	----------------------------------------------------
	next if ( $secRTIdx == -1 || $rtAutofill !~ /^[AGC]$/ || $washTrade );

	my $nonRTIdx = 1 - $secRTIdx;

	my ( @po , @trdrID );
	foreach my $idx ( 0 .. 1 ) {
		$po[ $idx ] = $msg->getAttr ( "BrokerNumber" , $idx );
		$trdrID[ $idx ] = $msg->getAttr ( "UserId" , $idx );
	}
	
	my $sym = $msg->getAttr ( "Symbol" );
	my $vol = $msg->getAttr ( "Volume" );
	my $price = $msg->getAttr ( "Price" );
	my $hiLo = ( $price >= 1 ? "H" : "L" );
	
#	Treat cancellations as negative volume.
#	---------------------------------------
	my $mult = ( $msg->getAttr ( "BusinessAction" ) eq 'Cancelled' ? -1 : 1 );
	
	print join ( "," , $msg->date , $msg->timeStamp , $po[ $nonRTIdx ] , $trdrID[ $nonRTIdx ] , $po[ $secRTIdx ] , $trdrID[ $secRTIdx ] , $rtAutofill , 
						$sym , $vol * $mult , $price , $hiLo ) , "\n";
}
