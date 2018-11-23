#!c:/perl/bin/perl

use strict;

my ( $loc , $tagVal , $tagTxt , $tagReqd , @tagDesc );

binmode STDOUT;

while ( <> ) {
	chomp;
#	print "[[$_]]\n";
	
	if ( /^\d+$/ ) {
		if ( ( $tagVal ) && scalar ( @tagDesc ) > 0 ) {
#			print "$tagVal,$tagTxt,$tagReqd,\"" , join ( "\012" , @tagDesc ) , "\"\015\012";
			print "$tagVal,$tagTxt,$tagReqd\n";
		}
		@tagDesc =();
		$tagVal = $_;
		$loc = "TAGVAL";
	}
	elsif ( $loc eq "TAGVAL" ) {
		$loc = "TAGTXT";
		$tagTxt = $_;
	}
	elsif ( $loc eq "TAGTXT" ) {
		$loc = "TAGREQD";
		$tagReqd = $_;
	}
	else {
		if ( $loc = "TAGREQD" ) {
			$loc = "TAGDESC";
		}
		push ( @tagDesc , $_ );
	}
}

if ( @tagDesc ) {
#	print "$tagVal,$tagTxt,$tagReqd,\"" , join ( "\012" , @tagDesc ) , "\"\015\012";
	print "$tagVal,$tagTxt,$tagReqd\n";
}
		
