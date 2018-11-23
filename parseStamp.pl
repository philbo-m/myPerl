#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use STAMPMsg;

# TransportHeader
#  ControlHeader - 0x01,ControlHeaderFlds
#   BusinessContent - 0x1c,BusinessContentFlds (0x1e,Fld=Val)
#  ControlTrailer - 0x1d,ControlTrailerFlds

my ( $ctrlHdr , $busCont , $ctrlTrlr , $fldSep ) 
	= ( chr ( 0x01 ) , chr ( 0x1c ) , chr ( 0x1d ) , chr ( 0x1e ) );

# local $/ = $ctrlHdr;

while ( <> ) {
	chomp;
	print STDERR "$.\n" if ( !( $. % 1000000 ) );
	
	my $msg = new STAMPMsg ();
	$msg->parse ( $_ );
	print $msg->dump , "\n";
}
