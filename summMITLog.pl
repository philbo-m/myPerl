#!c:/perl/bin/perl


# SESSION_ID,BROKER_ID,DMAGW_ORDER_ID,ORDER_ID,ORDER_PHASE,
# ORDER_QUANTITY,ORDER_TYPE,POSTED_MARKET,PRICE,PARENT_ORDER_ID,
# SIDE,SYMBOL,TIME_IN_FORCE,TRANSACTION_TIME,UMIR_USER_ID,
# IGW_CLIENT_ORDER_ID,IGW_MSG_RECIEVED_TIME,DMAGW_MSG_SENT_TIME,FWD_LATENCY

my %latencyMap = ();
my $SESSION = '101SOR03';

while ( <> ) {
	chomp;
	my ( $sessID , $recdTime , $latency ) = ( split /,/ )[ 0 , 16 , 18 ];
	
	$recdTime =~ s/...$//;
	$latencyMap{ $recdTime }{ 'TOTAL' }{ 'COUNT' }++;
	$latencyMap{ $recdTime }{ 'TOTAL' }{ 'LATENCY' } += $latency;
	
	if ( $sessID eq $SESSION ) {
		$latencyMap{ $recdTime }{ $sessID }{ 'COUNT' }++;
		$latencyMap{ $recdTime }{ $sessID }{ 'LATENCY' } += $latency;
	}
}

print "Time,Total Orders,$SESSION Orders,Total Avg Latency,$SESSION Avg Latency\n";

foreach my $time ( sort keys %latencyMap ) {
	my $map = $latencyMap{ $time };
	my $totCount = $$map{ 'TOTAL' }{ 'COUNT' };
	my $myCount = $$map{ $SESSION }{ 'COUNT' };
	printf "%s,%d,%d,%.2f,%.2f\n" ,
				$time , $totCount , $myCount ,
				$$map{ 'TOTAL' }{ 'LATENCY' } / $totCount ,
				( $myCount == 0 ? 0 : $$map{ $SESSION }{ 'LATENCY' } / $myCount );
}