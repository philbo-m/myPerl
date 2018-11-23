#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(..):(..):(..)\.(.+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 * 1000000 ) + ( $tp[ 2 ] * 60 * 1000000 ) + ( $tp[ 3 ] * 1000000 ) + $tp[ 4 ];
	}
	return abs ( $ts[ 1 ] - $ts[ 0 ] );
}

my %ignoreMsgs = map { $_ => 1 } qw ( 0 1 2 4 5 A MC MR f);
my %toMktMsgs = map { $_ => 1 } qw ( D F G );
	
my @msgBufs = ( [] , [] );

while ( <> ) {

#	ULLINK-specific pattern matching stuff.
#	---------------------------------------
	next if ( ! /\s(Sending|Receiving)\s:\s/ || /\s<.*\/>$/ || /_RELAY/ );
	
	chomp;
	
	my ( $date , $time , $thread , $plugin , $lvl , $dir , undef , $msg ) = split ( /\s+/ , $_ , 8 );
	
	my @msg = split ( /(?:\||^)(\d+)=/ , $msg );
	shift @msg;
	my %msg = @msg;
	
	( $msg{ "TS" } = $time ) =~ s/_//g;
	$plugin =~ s/[\[\]]//g;
	$msg{ "PLUGIN" } = $plugin;
	
	my $msgType = $msg{ "35" };

	next if exists $ignoreMsgs{ $msgType };
	
	my $isToMkt = ( exists $toMktMsgs{ $msgType } ? 1 : 0 );
	my $msgBuf = $msgBufs[ $isToMkt ];

	if ( $dir eq 'Receiving' ) {
#		print STDERR "Adding to buf [$isToMkt] : $msg{ 'TS' } | $msg{ '35' } | $msg{ '11' }\n";
		push @$msgBuf , \%msg;
	}
	else {
#		print STDERR "Looking in [$isToMkt] buf for : $msg{ 'TS' } | $msg{ '35' } | $msg{ '11' }\n";
		my ( $matchMsg , $found );
		foreach my $i ( 0 .. $#$msgBuf ) {
			$matchMsg = $$msgBuf[ $i ];
#			print STDERR "...$$matchMsg{ 'TS' } | $$matchMsg{ '35' } | $$matchMsg{ '11' }\n";
			if ( $$matchMsg{ "35" } eq $msgType && $$matchMsg{ "11" } eq $msg{ "11" } ) {
				splice ( @$msgBuf , $i , 1 );
				$found = 1;
				last;
			}
		}
		if ( !$found ) {
#			print STDERR "...$msg{ 'TS' } | $msg{ '35' } | $msg{ '150' } | $msg{ '11' } : NOT FOUND\n";
		}
		else {
			my ( $cltMsg , $mktMsg ) = ( $isToMkt ? ( $matchMsg , \%msg ) : ( \%msg , $matchMsg ) );
			print join ( "," , 
					(
						$$cltMsg{ 'PLUGIN' } ,
						$$mktMsg{ 'PLUGIN' } ,
						$msgType ,
						$msg{ '150' } ,
						$$matchMsg{ 'TS' } ,
						$msg{ 'TS' } ,
						tsDiff ( $msg{ 'TS' } , $$matchMsg{ 'TS' } )
					)
				) , "\n";
		}
	}
}

foreach my $bufIdx ( 1 , 0 ) {
	my $n = scalar @{ $msgBufs[ $bufIdx ] };
	print STDERR "$n unmatched msgs from " , ( $bufIdx == 1 ? "client" : "market" ) , ":\n";
	foreach my $msg ( @{ $msgBufs[ $bufIdx ] } ) {
		print STDERR join ( "|" , map { "$_=$$msg{ $_ }" } keys %$msg ) , "\n";
	}
}
