#!c:/perl/bin/perl

use strict;

sub totalLast {
	( $a eq 'TOTAL' ? 1 : ( $b eq 'TOTAL' ? -1 : $a cmp $b ) );
}
	
my @thresholds = ( 0.999 , 0.99 , 0.80 , 0.50 );
my %count = ();
my %total = ();
my %latTotal = ();
my %outliers = ();

while ( <> ) {
	chomp;
	my ( $msgType , $latency ) = ( split /,/ )[ 0 , 3 ];
	next if $latency !~ /^\d+$/;
	
	if ( $latency > 5000000 ) {
		$outliers{ $msgType }++;
		$outliers{ "TOTAL" }++;
	}
	else {
		$count{ $msgType }{ $latency }++;
		$count{ "TOTAL" }{ $latency }++;
		$total{ $msgType }++;
		$total{ "TOTAL" }++;
		$latTotal{ $msgType } += $latency;
		$latTotal{ "TOTAL" } += $latency;
	}
}

print "Msg Type,Total Msgs,Outliers,Max,Min,Avg";
foreach ( @thresholds ) {
	printf ( ",%.1f %%" , $_ * 100 );
}
print "\n";

foreach my $msgType ( sort totalLast keys %total ) {
	my @lclThresh = @thresholds;
	my $total = $total{ $msgType };
	my $latTotal = $latTotal{ $msgType };
	my $cum = 0;
	my $thresh = shift @lclThresh;
	my @latencies = reverse sort { $a <=> $b } keys %{ $count{ $msgType } };
	printf "$msgType,$total,%d,$latencies[ 0 ],$latencies[ $#latencies ],%d" , $outliers{ $msgType } , $latTotal / $total;
	foreach my $latency ( reverse sort { $a <=> $b } keys %{ $count{ $msgType } } ) {
		$cum += $count{ $msgType }{ $latency };
		if ( $cum / $total > 1. - $thresh ) {
			print ",$latency";
			last if !@lclThresh;
			$thresh = shift @lclThresh;
		}
	}	
	print "\n";
}		