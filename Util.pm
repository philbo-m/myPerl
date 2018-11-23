package Util;

use strict;
use Time::Local;

our $WILDCARD = "*";

sub isBetterPrice {

#   Returns 1 if price is better (more aggressive) than ref price,
#   0 if equal, -1 if worse
#   --------------------------------------------------------------
	my ( $price , $refPrice , $side ) = @_;
	if ( $side eq 'ASK' && !$refPrice ) {
		$refPrice = 99999;
	}
	my $cmp = ( $price <=> $refPrice );
	return ( $side eq 'ASK' ? -$cmp : $cmp );
}

sub isNumeric {
	my ( $val ) = @_;
	
	return ( $val =~ /^-?(\d+|\d*\.\d+)$/ );
}

sub transformQty {
	my ( $subProd , $qty ) = @_;
	if ( $subProd =~ /_DEBT/ ) {
		$qty /= 100;
	}
	return $qty;
}

sub lastDayOfMonth {
	my ( $yyyy , $mm ) = @_;	# --- 20xx, 1-12 (month is one-based, here) ---
	$mm++;
	if ( $mm > 12 ) {
		$yyyy++;
		$mm -= 12;
	}
	my $dd;
	my $time = timelocal ( 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 );
	$time -= 86400;
	( $dd , $mm , $yyyy ) = ( localtime ( $time ) )[ 3 .. 5 ];
	return sprintf "%02d/%02d/%4d" , $mm + 1 , $dd , $yyyy + 1900;
}

sub prevMonth {
	my ( $yyyy , $mm ) = @_;	# --- 20xx, 1-12 (month is one-based, here) ---
	if ( !$yyyy ) {
	
#		Set to current month/year if not specified.
#		-------------------------------------------
		( $mm , $yyyy ) = ( localtime ( time ) )[ 4 , 5 ];
		$mm++ ; $yyyy += 1900;
	}
	
	$mm--;
	if ( $mm <= 0 ) {
		$yyyy--;
		$mm += 12;
	}
	return ( $yyyy , $mm );
}

sub addToHash {
	my ( $hash , $keys , $val , $idx ) = @_;
	$idx += 0;
	my $key = $$keys[ $idx ];
	if ( $idx == $#$keys ) {
		$$hash{ $key } += $val;
	}
	else {
		foreach ( $WILDCARD , $key ) {
			if ( !exists $$hash{ $_ } ) {
				$$hash{ $_ } = {};
			}
			addToHash ( $$hash{ $_ } , $keys , $val , $idx + 1 );
		}
	}
}

sub cmpVals {
	my ( $v1 , $v2 , $tolerance , $desc ) = @_;
	my $retVal = valMatch ( $v1 , $v2 , $tolerance );
	if ( !$retVal ) {
		printf STDERR "$desc,$v1,$v2,%.2f\n" , $v2  - $v1;
	}
	return $retVal;
}

sub valMatch {
	my ( $v1 , $v2 , $tolerance ) = @_;

	$v1 = 0 if $v1 eq '' ; $v2 = 0 if $v2 eq '';
	
#	--- Short-circuit if non-numeric ---
	if ( !isNumeric ( $v1 ) || !isNumeric ( $v2 ) ) {
		return ( $v1 eq $v2 );
	}
	my ( $absTolerance , $relTolerance ) = ( 0 , 0 );
	if ( $tolerance ) {
		my $ref = ref ( $tolerance );
		if ( !$ref ) {
			$absTolerance = $tolerance;
		}
		elsif ( $ref eq 'HASH' ) {
			$absTolerance = $$tolerance{ ABS } if exists $$tolerance{ ABS };
			$relTolerance = $$tolerance{ REL } if exists $$tolerance{ REL };
		}
		else {
			die "Tolerance arg to valMatch must be numeric or a { ABS => x , REL => y } hashref"
		}
	}

	my $diff = abs ( $v1 - $v2 );
	return ( 
		$diff < $absTolerance || $diff / ( abs ( $v1 ) + abs ( $v2 ) ) < $relTolerance
	);

#	if ( defined $absThresh ) {
#		return ( abs ( $v1 - $v2 ) < $absThresh );
#	}
#	else {
#		return
#			( abs ( $v1 - $v2 ) < 0.01 ) || 
#			( ( abs ( $v1 ) < 0.05 || abs ( $v2 ) < 0.05 ) && abs ( $v1 - $v2 ) < 0.10 ) ||
#			( abs ( ( $v1 - $v2 ) / ( abs ( $v1 ) + abs ( $v2 ) ) ) < .005 )
#		;
#	}
}

sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(..):(..):(..)\.(.+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 * 1000000 ) + ( $tp[ 2 ] * 60 * 1000000 ) + ( $tp[ 3 ] * 1000000 ) + $tp[ 4 ];
	}
	return ( $ts[ 1 ] - $ts[ 0 ] );
}

sub timeDiff {
	my ( $time1 , $time2 ) = @_;
	my ( $h1 , $m1 , $s1 ) = split ( /:/ , $time1 );
	my ( $h2 , $m2 , $s2 ) = split ( /:/ , $time2 );
	return ( ( $h2 - $h1 ) * 3600 ) + ( ( $m2 - $m1 ) * 60 ) + ( $s2 - $s1 );
}

sub max {
	my ( $a , $b ) = @_;
	return ( $a > $b ? $a : $b );
}

sub min {
	my ( $a , $b ) = @_;
	return ( $a > $b ? $b : $a );
}


1;