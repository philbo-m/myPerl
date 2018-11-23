#!/usr/bin/env perl

use strict;
use Getopt::Long;
use File::Basename;
my $scriptName = basename $0;

use STAMP::STAMPStream;

sub usageAndExit {
	print STDERR "Usage : $scriptName [-b] [-t threshTime]\n";
	print STDERR "  Use '-b' for 'binary mode' with record delimiters = hex 001.\n";
	print STDERR "  Use '-t' to specify a threshold (cutoff) time (format HH:MM[:SS]).\n";
	
	exit 1;
}

my $recordSep = "\n";
my ( $binaryMode , $threshTime );

GetOptions ( 
	'b'		=> \$binaryMode ,
	't=s'	=> \$threshTime
) or usageAndExit;

if ( $binaryMode ) {
	$recordSep = chr ( 001 );
}
if ( $threshTime ) {
	if ( $threshTime =~ /^([01][0-9]):([0-5][0-9])(:([0-5][0-9]))?$/ ) {
		$threshTime = $1 . $2 . ( $4 eq '' ? '00' : $4 ) . '000000000';
	}
	else {
		usageAndExit;
	}
}
kkk
my %volBySym = ();

my $stream = new STAMP::STAMPStream ( Debug => 0 , SkipOrders => 1 , RecordSep => $recordSep );

while ( my $msg = $stream->next ) {

	next if !( $msg->isa ( "STAMP::STAMPTradeMsg" ) );	# --- we don't care about anything other than Trade msgs ---
	last if ( $threshTime && $msg->getAttr ( 'TimeStamp' ) gt $threshTime ); # --- ...or anything past our specified threshold time ---

#	--- Skip crosses ---
	next if ( $msg->getAttr ( 'CrossType' ) );	# --- skip crosses ---
	
#	---Skip all Auction activity ---
	my $exchAdmin = $msg->getAttr ( "Exchange-Admin" , 0 );
	next if ( substr ( $exchAdmin , 2 , 1 ) ne 'P' );

#	--- We know we're counting this trade now ---
	my $sym = $msg->getAttr ( "Symbol" );
	my $vol = $msg->getAttr ( "Volume" );
	$vol *= -1 if $msg->getAttr ( "BusinessAction" ) eq 'Cancelled';
	$volBySym{ $sym }{ ALL } += $vol;
	
#	--- Check if either side of the trade is passive Dark ---
	my $isPsvDark;
	foreach my $idx ( 0 , 1 ) {
		if ( $msg->getAttr ( "Undisplayed" , $idx ) ) {
			my $idxExchAdmin = ( $idx == 0 ? 
									$exchAdmin : 
									$msg->getAttr ( "Exchange-Admin" , $idx ) 
								);
			if ( substr ( $idxExchAdmin , 1 , 1 ) eq 'P' ) {
				$isPsvDark = 1;
				last;
			}
		}
	}
	$volBySym{ $sym }{ DARK } += $vol if $isPsvDark;
}

exit;
printf "Symbol,Total Vol,Dark Vol\n";

foreach my $sym ( sort keys %volBySym ) {
	printf $sym;
	foreach my $key ( qw ( ALL DARK ) ) {
		printf ",%d" , $volBySym{ $sym }{ $key };
	}
	print "\n";
}