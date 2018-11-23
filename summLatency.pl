#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

use FIXFld;

use Data::Dumper;

my $totalStr = "*";

sub totalLast {
	( $a eq $totalStr ? 1 : ( $b eq $totalStr ? -1 : $a cmp $b ) );
}
sub totalFirst {
	( $a eq $totalStr ? -1 : ( $b eq $totalStr ? 1 : $a cmp $b ) );
}

my @thresholds = ( 0.999 , 0.99 , 0.80 , 0.50 );
my %count = ();
my %total = ();
my %latTotal = ();
my %outliers = ();
my %msgTypes = (
	$totalStr	=> {
		$totalStr	=> 1
	}
);

while ( <> ) {
	chomp;
	my ( $cltPlugin , $mktPlugin , $msgType , $execType , undef , undef , $latency ) = split /,/;
#	print "[$cltPlugin] [$mktPlugin] [$msgType] [$execType] [$latency]\n";
	next if $latency !~ /^\d+$/;
	
	$execType = "NONE" if $execType eq '';
	$msgTypes{ $msgType }{ $execType } = 1;
	$msgTypes{ $msgType }{ $totalStr } = 1;
	
	if ( $latency > 5000000 ) {
		$outliers{ $msgType }++;
		$outliers{ $totalStr }++;
	}
	else {
		$count{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType }{ $latency }++;
		$count{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $totalStr }{ $latency }++;
		$count{ $cltPlugin }{ $mktPlugin }{ $totalStr }{ $totalStr }{ $latency }++;
		$count{ $cltPlugin }{ $totalStr }{ $msgType }{ $execType }{ $latency }++;
		$count{ $cltPlugin }{ $totalStr }{ $msgType }{ $totalStr }{ $latency }++;
		$count{ $cltPlugin }{ $totalStr }{ $totalStr }{ $totalStr }{ $latency }++;
		$count{ $totalStr }{ $totalStr }{ $msgType }{ $execType }{ $latency }++;
		$count{ $totalStr }{ $totalStr }{ $msgType }{ $totalStr }{ $latency }++;
		$count{ $totalStr }{ $totalStr }{ $totalStr }{ $totalStr }{ $latency }++;

		$total{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType }++;
		$total{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $totalStr }++;
		$total{ $cltPlugin }{ $mktPlugin }{ $totalStr }{ $totalStr }++;
		$total{ $cltPlugin }{ $totalStr }{ $msgType }{ $execType }++;
		$total{ $cltPlugin }{ $totalStr }{ $msgType }{ $totalStr }++;
		$total{ $cltPlugin }{ $totalStr }{ $totalStr }{ $totalStr }++;
		$total{ $totalStr }{ $totalStr }{ $msgType }{ $execType }++;
		$total{ $totalStr }{ $totalStr }{ $msgType }{ $totalStr }++;
		$total{ $totalStr }{ $totalStr }{ $totalStr }{ $totalStr }++;

		$latTotal{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType } += $latency;
		$latTotal{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $totalStr } += $latency;
		$latTotal{ $cltPlugin }{ $mktPlugin }{ $totalStr }{ $totalStr } += $latency;
		$latTotal{ $cltPlugin }{ $totalStr }{ $msgType }{ $execType } += $latency;
		$latTotal{ $cltPlugin }{ $totalStr }{ $msgType }{ $totalStr } += $latency;
		$latTotal{ $cltPlugin }{ $totalStr }{ $totalStr }{ $totalStr } += $latency;
		$latTotal{ $totalStr }{ $totalStr }{ $msgType }{ $execType } += $latency;
		$latTotal{ $totalStr }{ $totalStr }{ $msgType }{ $totalStr } += $latency;
		$latTotal{ $totalStr }{ $totalStr }{ $totalStr }{ $totalStr } += $latency;
	}
}

# print Dumper ( \%total ) , "\n";

# Assemble and print the header.
# ------------------------------
my @hdrRecs = (
	[ "Client Plugin" , "Venue Plugin" ] ,
	[ "" , "" ]
);

foreach my $msgType ( sort totalFirst keys %msgTypes ) {
	my $mTxt = ( $msgType eq $totalStr ? $msgType : $FIXFld::valMap{ 35 }{ $msgType } );
	foreach my $execType ( sort totalFirst keys %{ $msgTypes{ $msgType } } ) {
		my $eTxt = ( $execType eq $totalStr ? $execType : $FIXFld::valMap{ 150 }{ $execType } );
		my $meTxt = $mTxt . ( $eTxt ne '' ? "/$eTxt" : "" ); 
		push @{ $hdrRecs[ 0 ] } , ( $meTxt , "" , "" , "" );
		push @{ $hdrRecs[ 1 ] } , ( "COUNT" , "MAX" , "MIN" , "AVG" );
		foreach my $thresh ( @thresholds ) {
			push @{ $hdrRecs[ 0 ] } , "";
			push @{ $hdrRecs[ 1 ] } , sprintf ( "%f%%" , $thresh * 100 );
		}
	}
}
foreach my $rec ( @hdrRecs ) {
	print join ( "," , @$rec ) , "\n";
}
		
foreach my $cltPlugin ( sort totalLast keys %total ) {	
	foreach my $mktPlugin ( sort totalLast keys %{ $total{ $cltPlugin } } ) {
		
		print "$cltPlugin,$mktPlugin";
		
		foreach my $msgType ( sort totalFirst keys %msgTypes ) {
			foreach my $execType ( sort totalFirst keys %{ $msgTypes{ $msgType } } ) {
			
				my $total = $total{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType };
				my $latTotal = $latTotal{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType };
				my $cntMap = $count{ $cltPlugin }{ $mktPlugin }{ $msgType }{ $execType };

				if ( !$total ) {
					print ",0,---,---,---," , join ( "," , map { "---" } @thresholds );
					next;
				}
					
				my @latencies = reverse sort { $a <=> $b } keys %$cntMap;
				
				printf ",%d,%d,%d,%d" , $total , $latencies[ 0 ] , $latencies[ $#latencies ] , 
										( $total == 0 ? 0 : $latTotal / $total );
				
				my $cum = 0;
				my $threshIdx = 0;
				my $thresh = $thresholds[ $threshIdx ];
				my $latency;
				foreach ( reverse sort { $a <=> $b } keys %$cntMap ) {
					$latency = $_;
					$cum += $$cntMap{ $latency };
					if ( $cum / $total > 1. - $thresh ) {
						print ",$latency";
						last if ++$threshIdx > $#thresholds;
						$thresh = $thresholds[ $threshIdx ];
					}
				}
				for ( $threshIdx .. $#thresholds ) {
					print ",$latency";
				}
			}
		}
		print "\n";
	}
}		