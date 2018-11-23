#!c:/perl/bin/perl

use strict;
use Getopt::Long;

my @THRESH = ( 0.999 , 0.99 );

sub todToTime {
	my ( $tod ) = @_;
	my ( $h , $m , $s ) = split ( /:/ , $tod );
	return ( $h * 3600 + $m * 60 + $s );
}
sub timeToTod {
	my  ( $time ) = @_;
	return sprintf ( "%02d:%02d:%02d" , $time / 3600 , ( $time % 3600 ) / 60 , $time % 60 );
}

my $mktOpenTime ='9:30:00';
my $mktCloseTime = '16:00:00';

GetOptions ( 
	's=s'	=> \$mktOpenTime ,
	'e=s'	=> \$mktCloseTime
) or die;

$mktOpenTime = todToTime ( $mktOpenTime );
$mktCloseTime = todToTime ( $mktCloseTime );
my @mktSecs = ( $mktOpenTime .. $mktCloseTime );
my %mktSecMap = map { $_ => 1 } @mktSecs;
my %rateByHubDateTime = ();
my %dateMap = ();

#foreach my $file ( @ARGV ) {
#	open FILE , $file or die "Cannot open daily file $file : $!";

	while ( <> ) {
#	while ( <FILE> ) {
		chomp;
		my ( $date , $tod , $firm , $hub , $rate ) = ( split /,/ )[ 0 , 1 , 3 , 4 , 5 ];

#		Compatibility with ULLINK reports, which lack the HUB field.
#		------------------------------------------------------------
		if ( !$rate ) {
			$rate = $hub;
			$hub = "ALL";
		}
		$hub = "ALL";

		next if $rate !~ /^\d*$/;
		my $time = todToTime ( $tod );
#		print "[$_] [$time] [$tod] [$rate]\n";
		next if ( !exists $mktSecMap{ $time } );	# --- skip if outside mkt hrs ---
		
		$dateMap{ $date } = 1;
		
		my $dateTime = $date . "," . $time;
		$rateByHubDateTime{ $hub }{ $dateTime } += $rate;
	}
#	close FILE;
# }

my %maxRateByHubTime = ();
foreach my $hub ( keys %rateByHubDateTime ) {
	foreach my $dateTime ( keys %{ $rateByHubDateTime{ $hub } } ) {
		my ( $date , $time ) = split /,/ , $dateTime;
		my $rate = $rateByHubDateTime{ $hub }{ $dateTime };
		$maxRateByHubTime{ $hub }{ $time } = $rate if $rate > $maxRateByHubTime{ $hub }{ $time };
	}
}

foreach my $hub ( keys %maxRateByHubTime ) {
	foreach my $time ( keys %{ $maxRateByHubTime{ $hub } } ) {
#		print "$hub," , timeToTod ( $time ) , ",$maxRateByHubTime{ $hub }{ $time }\n";
	}
}
# exit;

my $totTimes = ( scalar keys %dateMap ) * ( scalar keys %mktSecMap );

print "Hub,MaxDate,MaxTime,MaxRate," , join ( "," , map { $_ * 100 . "% Rate" } @THRESH  ) , ",AvgRate\n";

foreach my $hub ( keys %rateByHubDateTime ) {
	my $rateByDateTime = $rateByHubDateTime{ $hub };
	my ( $maxDate , $maxTime , $maxRate , $totRate );
	foreach my $dateTime ( reverse sort { $$rateByDateTime{ $a } <=> $$rateByDateTime{ $b } } keys %$rateByDateTime ) {
		my ( $date , $time ) = split /,/ , $dateTime;
		my $rate = $$rateByDateTime{ $dateTime };
		if ( !$maxDate ) {
			$maxDate = $date;
			$maxTime = $time;
			$maxRate = $$rateByDateTime{ $dateTime };
		}
		$totRate += $rate;
#		print "$hub,$date," , timeToTod ( $time )  , ",$$rateByDateTime{ $dateTime }\n";
	}
	
	my @rateList = reverse sort { $a <=> $b } values %$rateByDateTime;
	print "$hub,$maxDate," , timeToTod ( $maxTime ) , ",$maxRate";
	foreach my $thresh ( @THRESH ) {
		print "," , $rateList[ $totTimes * ( 1. - $thresh ) ];
	}
	printf ",%.1f\n" , ( $totRate / $totTimes );
}

