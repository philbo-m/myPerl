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
	my ( $plugin , $exDest , $msgType , $execMsgType , $execType , $ts , $latency ) = ( split /,/ )[ 0 , 3 , 4 , 5 , 6 , 7 , 9 ];
	next if $latency !~ /^\d+$/;
	
#	Restrict to 09:31:00 - 15:59:00..
#	---------------------------------
	next if ( $ts lt "09:31:00.000000" || $ts gt "15:59:00.000000" );
	
	$msgType = $FIXFld::valMap{ 35 }{ $msgType };
	if ( $execType ne '' ) {
		$execType = $FIXFld::valMap{ 150 }{ $execType };
	}
	else {
		$execType = $FIXFld::valMap{ 35 }{ $execMsgType };
	}
	if ( $msgType eq 'Single Order' ) {
		if ( $execType =~ /New|Fill/ ) {
			$execType = 'New|Filled';
		}
	}
		
	$msgTypes{ $msgType }{ $execType } = 1;
	$msgTypes{ $msgType }{ $totalStr } = 1;

#	next if $plugin =~ /SOR/;	# --- skip SOR sessions ---
	$plugin =~ s/^.*?_//;
	$plugin =~ s/_\d((_L)?)$/$1/;	# --- collapse TSX and TSXV partitions into single destinations ---
	$plugin =~ s/_OLLP/_LQDTY/;	# --- collapse TRIACT_OLLP into TRIACT_LQDTY ---
	
	if ( $latency > 5000000 ) {
		$outliers{ $msgType }++;
		$outliers{ $totalStr }++;
	}
	else {
		$count{ $plugin }{ $msgType }{ $execType }{ $latency }++;
		$count{ $plugin }{ $msgType }{ $totalStr }{ $latency }++;
		$count{ $plugin }{ $totalStr }{ $execType }{ $latency }++;
		$count{ $plugin }{ $totalStr }{ $totalStr }{ $latency }++;
		$count{ $totalStr }{ $msgType }{ $execType }{ $latency }++;
		$count{ $totalStr }{ $msgType }{ $totalStr }{ $latency }++;
		$count{ $totalStr }{ $totalStr }{ $execType }{ $latency }++;
		$count{ $totalStr }{ $totalStr }{ $totalStr }{ $latency }++;

		$total{ $plugin }{ $msgType }{ $execType }++;
		$total{ $plugin }{ $msgType }{ $totalStr }++;
		$total{ $plugin }{ $totalStr }{ $execType }++;
		$total{ $plugin }{ $totalStr }{ $totalStr }++;
		$total{ $totalStr }{ $msgType }{ $execType }++;
		$total{ $totalStr }{ $msgType }{ $totalStr }++;
		$total{ $totalStr }{ $totalStr }{ $execType }++;
		$total{ $totalStr }{ $totalStr }{ $totalStr }++;

		$latTotal{ $plugin }{ $msgType }{ $execType } += $latency;
		$latTotal{ $plugin }{ $msgType }{ $totalStr } += $latency;
		$latTotal{ $plugin }{ $totalStr }{ $execType } += $latency;
		$latTotal{ $plugin }{ $totalStr }{ $totalStr } += $latency;
		$latTotal{ $totalStr }{ $msgType }{ $execType } += $latency;
		$latTotal{ $totalStr }{ $msgType }{ $totalStr } += $latency;
		$latTotal{ $totalStr }{ $totalStr }{ $execType } += $latency;
		$latTotal{ $totalStr }{ $totalStr }{ $totalStr } += $latency;
	}
}

# Assemble and print the header.
# ------------------------------
my @hdrRecs = (
	[ "Plugin" ] ,
	[ "" ]
);

foreach my $msgType ( sort totalFirst keys %msgTypes ) {
	foreach my $execType ( sort totalFirst keys %{ $msgTypes{ $msgType } } ) {
		my $meTxt = "${msgType}/${execType}"; 
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
		
foreach my $plugin ( sort totalLast keys %total ) {	
	print "$plugin";
		
	foreach my $msgType ( sort totalFirst keys %msgTypes ) {
	
		foreach my $execType ( sort totalFirst keys %{ $msgTypes{ $msgType } } ) {
		
			my $total = $total{ $plugin }{ $msgType }{ $execType };
			my $latTotal = $latTotal{ $plugin }{ $msgType }{ $execType };
			my $cntMap = $count{ $plugin }{ $msgType }{ $execType };

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