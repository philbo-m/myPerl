#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Time::Local;

sub fmtTS {
	my ( $ts , $prec ) = @_;
	my ( $hm , $sFrac ) = ( $ts =~ /^(\d+:\d+):([\d.]+)$/ );
	
	return sprintf "%s:%s%.0${prec}f" , $hm , ( $sFrac < 10 ? "0" : "" ) , $sFrac;
}

sub tsAdd {
	my ( $ts , $incr ) = @_;
	my ( $h , $m , $s , $frac ) = split ( /[:.]/ , $ts );
	my $fracLen = length ( $frac );
	my $time = timelocal ( $s , $m , $h , 1 , 1 , 1 );
	$time .= ".${frac}" if $frac;
	$time += $incr;
	$frac = $time - int ( $time );
	( $h , $m , $s ) = ( localtime ( int ( $time ) ) )[ 2 , 1 , 0 ];
	$s += $frac;
	
	return sprintf ( "%02d:%02d:%s%.0${fracLen}f" , $h , $m , ( $s < 10 ? "0" : "" ) , $s );
}


sub getPrevXVal {
	my ( $xVal  , $prec , $tsFlag ) = @_;
	my $subVal = 1;
	for ( 1 .. $prec ) { $subVal *= 10 };
	if ( $tsFlag ) {
		return tsAdd ( $xVal , -( 1 / $subVal ) );
	}
	else {
		return $xVal - 1 / $subVal;
	}
}

		
my ( $xAxisFld , $yAxisFld , $tsFlag , $numDecPlaces );

GetOptions ( 
	'x=i'	=> \$xAxisFld ,
	'y=i'	=> \$yAxisFld ,
	't'		=> \$tsFlag ,
	'd=i'	=> \$numDecPlaces
) or die;

$xAxisFld-- ; $yAxisFld--;

my ( $prevXVal , $prevYVal );
my ( $minXVal , $maxXVal ) = ( "09:30:00.000" , "16:00:00.000" );

while ( <> ) {
	chomp;
	my ( $xVal , $yVal ) = ( split /,/ )[ $xAxisFld , $yAxisFld ];
	if ( $tsFlag ) {
		$xVal = fmtTS ( $xVal , $numDecPlaces );
	}
	
	if ( !defined $prevXVal ) {
		print "$minXVal,$yVal\n";
	}
	elsif ( $prevXVal gt $xVal ) {
		print "$maxXVal,$prevYVal\n";
		print "$minXVal,$yVal\n";
	}

	$prevXVal = getPrevXVal ( $xVal , $numDecPlaces , $tsFlag );
	
	if ( $yVal != $prevYVal ) {
		if ( defined $prevYVal ) {
			print "$prevXVal,$prevYVal\n";
		}
		print "$xVal,$yVal\n";
	
		$prevYVal = $yVal;
	}
}
		