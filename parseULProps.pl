#!c:/perl/bin/perl

use strict;

# I_TRADEBOT1_SOR.session.sendercompid                       = ULLINK_SOR

my %sessMap = ();

while ( <> ) {
	chomp;
	next if ( /^\s*$/ || /^#/ );
	
	my ( $key , $val ) = split /\s+=\s+/;
	next if !$val;
	$val = "'${val}" if $val =~ /^0/;

	my ( $sessID, undef , $sessKey ) = split  ( /\./ , $key );
	next if $sessKey eq "prefix";

	my $side;
	( $side , $sessID ) = ( $sessID =~ /(.)_(.*)$/ );
	my $venue = ( split /_/ , $sessID )[ 1 ];
	
	if ( $sessID =~ /_TSX_/ && $side eq "O" ) {
		my $tsxDest;
		( $sessID , $tsxDest ) = ( $sessID =~ /^(.*_TSX)_(.*)$/ );
		if ( $tsxDest eq "SEL_XA" ) {
			$sessKey = "sel_${sessKey}";
		}
		elsif ( $tsxDest =~ /XA/ ) {
			$sessKey = "xa_${sessKey}";
			$val =~ s/K/[KLOP]/;
		}
		next if exists $sessMap{ $venue }{ $sessID }{ $side }{ $sessKey };
	}
	
	$sessMap{ $venue }{ $sessID }{ $side }{ $sessKey } = $val;
}

foreach my $venue ( sort keys %sessMap ) {
	foreach my $sessID ( sort keys %{ $sessMap{ $venue } } ) {
		my $map = $sessMap{ $venue }{ $sessID };
		print join ( "," , (
				$venue ,
				"I_${sessID}" ,
				$$map{ "I" }{ "targetcompid" } ,
				$$map{ "I" }{ "sendercompid" } ,
				$$map{ "I" }{ "client" } ,
				$$map{ "I" }{ "account" } ,
				$$map{ "O" }{ "sendercompid" } ,
				$$map{ "O" }{ "targetcompid" } ,
				$$map{ "O" }{ "xa_sendercompid" } ,
				$$map{ "O" }{ "sel_sendercompid" }
			) ) , "\n";
	}
}
