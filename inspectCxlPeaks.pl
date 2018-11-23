#!c:/perl/bin/perl

use strict;

sub getSpikes {
	my ( $date , $cntByTime , $cntThresh , $cntByTrdrID , $fracThresh ) = @_;
	foreach my $time ( sort keys %$cntByTime ) {
		my $cnt = $$cntByTime{ $time };
		next if $cnt < $cntThresh;
		
		print "$date,$time,$cnt\n";
		my $contribs = getBigContribs ( $cnt , $$cntByTrdrID{ $time } , $fracThresh );
		if ( scalar @$contribs ) {
			foreach my $trdrID ( @$contribs ) {
				print " $trdrID,$$cntByTrdrID{ $time }{ $trdrID }\n";
			}
		}
	}
}
			
sub getBigContribs {
	my ( $cnt , $cntByTrdrID , $thresh ) = @_;
	my @contribs = ();
	
	foreach my $trdrID ( sort { $$cntByTrdrID{ $b } <=> $$cntByTrdrID{ $a } } keys %$cntByTrdrID ) {
		my $trdrIDCnt = $$cntByTrdrID{ $trdrID };
		last if ( $trdrIDCnt / $cnt < $thresh );
		push @contribs , $trdrID;
	}
	
	return \@contribs;
}

my $cntThresh = 400;
my $fracThresh = 0.2;

my  ( $date , $prevDate , $time );
my %cntByTime = ();
my %cntByTrdrID = ();

while ( <> ) {
	next if not /,CXL(-CFO)?,/;
	
	chomp;
	my ( $timeStamp , $trdrID , $duration ) = ( split /,/ )[ 1 , 3 , 10 ];
	
	( $date , $time ) = ( $timeStamp =~ /^(.{8})(.{6})..$/ );
	next if ( $time < 93000 || $time > 160000 );
	
	next if $duration > 1000;

	if ( $date ne $prevDate ) {
		print STDERR "...$prevDate...\n";
		getSpikes ( $prevDate , \%cntByTime , $cntThresh , \%cntByTrdrID , $fracThresh );
		%cntByTime = ();
		%cntByTrdrID = ();
	}
	
	$cntByTime{ $time }++;
	$cntByTrdrID{ $time }{ $trdrID }++;	
	$prevDate = $date;
}

getSpikes ( $date , \%cntByTime , $cntThresh , \%cntByTrdrID , $fracThresh );


	
	