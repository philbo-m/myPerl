#!c:/perl/bin/perl

use strict;

my %compIdMap = (
	c => {
		TargetCompID	=> "ClientSenderCompID" ,
		OurCompID		=> "ClientTargetCompID"
	} ,
	m => {
		TargetCompID	=> "VenueTargetCompID" ,
		OurCompID		=> "VenueSenderCompID"
	}
);	

my @keys = qw ( Broker Firm Account ClientSenderCompID ClientTargetCompID VenueSenderCompID VenueTargetCompID );

my %sessMap = ();

while ( <> ) {
	next if /^#/;
	chomp;
	next if ( /^\s*$/ );
		
	my ( $sess , $key , $val , $qual ) = ( split /,/ )[ 6 , 7 , 9 , 10 ];
	my $side;
	( $side , $sess ) = ( $sess =~ /^(.)(.*)$/ );
	if ( exists $compIdMap{ $side }{ $key } ) {
		$key = $compIdMap{ $side }{ $key };
	}
	$sessMap{ $sess }{ $key } = $val;
#	print "[$sess] [$side] [$key] [$val]\n";
}

print "Session," , join ( "," , @keys ) , "\n";
foreach my $sess ( sort keys %sessMap ) {
	my @vals = ( $sess );
	foreach my $key ( @keys ) {
		push @vals , $sessMap{ $sess }{ $key };
	}
	print join ( "," , @vals ) , "\n";
}


