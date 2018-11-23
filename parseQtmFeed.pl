#!c:/perl/bin/perl

use strict;

my $bufSize = 1000000;

my @buffer = ();
my $tmpBuf;
my $totRead = 0;

my $i = 0;

while ( my $bufRead = read ( *STDIN , $tmpBuf , $bufSize ) ) {
	$totRead += $bufRead;
	push @buffer , split ( // , $tmpBuf );	
	print STDERR "Read buf...[$totRead] total...[" , scalar @buffer , "] in buffer...\n";
	
	while ( 1 ) {

#		Read frame header.
#		------------------
		my @frameHdr = splice ( @buffer , 0 , 5 );
		my $msgLen = unpack ( "s" , $frameHdr[ 3 ] . $frameHdr[ 4 ] );
		if ( scalar @frameHdr < 5 || $msgLen > scalar ( @buffer ) ) {
			splice @buffer , 0 , 0 , @frameHdr;
			last;
		}
		my @msg = splice ( @buffer , 0 , $msgLen );
		
		my @msgHdr = splice ( @msg , 0 , 6 );
		my $numBody = unpack ( "s" , $msgHdr[ 5 ] );
		
#		print STDERR "Hdr [@frameHdr] len [$msgLen] msg [@msg]\n";
		
		$msgLen = unpack ( "s" , join ( "" , splice ( @msg , 0 , 2 ) ) );
		my $msgType = unpack ( "a" , shift ( @msg ) );
		print "Msg [" , ++$i , "] type [$msgType] len [$msgLen] [@msg]\n";
	}
}
		