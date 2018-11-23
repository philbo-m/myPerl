#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use QFMessage;

sub hexDump {
	my ( $str ) = @_;
	return join ( " " , map { sprintf ( "%02x" , ord ( $_ ) ) } split ( // , $str ) );
}

binmode STDIN;
binmode STDOUT;

select STDOUT;
$| = 1;

my $chunkSize = 10000; # --- the bigger the chunk, the *slower* the program runs! ---

my $buffer;
my $tmpBuf;
my $totRead = 0;
my $bufSize = 0;

my $i = 0;

my $msgCount = 0;

my $pktHdrLen = 16;
my $ethHdrLen = 14;
my $vlanHdrLen = 4;
my $ipHdrLen = 20;
my $udpHdrLen = 8;
my $vlanTrlrLen = 4;

my $fullHdrLen = $pktHdrLen + $ethHdrLen + $vlanHdrLen + $ipHdrLen + $udpHdrLen;
my $payloadLenOffset = $fullHdrLen - $udpHdrLen + 4;

#	Initialize - find the first packet header:
#   [....][....][....][....]
#	 - 4-byte timestamp (secs)
#	 - 4-byte timestamp (usec)
#	 - capture length (1st char should never be zero)
#	 - packet length (ASSUMING - always equals capture length <-- HEURISTIC)
#	------------------------------------------------------------------------
$totRead = read ( *STDIN , $buffer , 1000 );
die "Insufficient data in STDIN" if $totRead != 1000;
print STDERR "Initial buf [" , length ( $buffer ) , "]\n[[" , hexDump ( $buffer ) , "]]\n";

my ( $garbage , $pfx , $p1 , $p2 ) = ( $buffer =~ /^(.*?)(.{8})([^\000]...)(\3)/s );
die ( "Cannot find initial message" ) if !$p2;

print STDERR "Initial repeated pattern [" , hexDump ( $garbage ) , "] [" , hexDump ( $pfx ) , "] [" , hexDump ( $p1 ) , "] [" , hexDump ( $p2 ) , "]\n";
my $discardLen = length ( $garbage );
$buffer = substr ( $buffer , $discardLen );
print STDERR "Initial buf now [" , length ( $buffer ) , "]\n[[" , hexDump ( $buffer ) , "]]\n";

$bufSize = length ( $buffer );

while ( 1 ) {
	my $bufRead = read ( *STDIN , $tmpBuf , $chunkSize );
	$totRead += $bufRead;
	$bufSize += $bufRead;
	
	print STDERR "Read [$bufRead] bytes total [$totRead]...\n";
	$buffer .= $tmpBuf;
	
	while ( 1 ) {

		last if ( $bufSize < 1000 );
		
		my $hdr = substr ( $buffer , 0 , $fullHdrLen );		
		my $payloadLen = unpack ( "n" , substr ( $hdr , $payloadLenOffset , 2 ) );
		
#		print STDERR "HDR [" , hexDump ( $hdr ) , "] payload len [$payloadLen]\n";
		
		$payloadLen -= $udpHdrLen - $vlanTrlrLen;	# --- subtract the UDP hdr len and add back the VLAN trlr len ---
		my $payload = substr ( $buffer , $fullHdrLen , $payloadLen );
		$payload =~ s/.{4}$//s;	# --- strip off the VLAN trlr ---
		
#		print STDERR "PAYLOAD [" , ++$msgCount , "] [" , length ( $payload ) , "] [" , hexDump ( $payload ) , "]\n";
		print "$payload";
		
		my $pktLen = $fullHdrLen + $payloadLen; # --- remember payloadLen already includes vlanTrlrLen ---
		$buffer = substr ( $buffer , $pktLen );
		$bufSize -= $pktLen;
#		print STDERR "Buffer len after [$pktLen] parsed now [" , length ( $buffer ) , "]\n";

		my $msg = new QFMessage ( msg => $payload );
	}
	
	last if !$bufRead;
}