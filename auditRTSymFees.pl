#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::SymbolSumm;

sub correctRTNetFees {
	my ( $feeMap , $symList ) = @_;
	
	foreach my $sym ( @$symList ) {
		my $totBasicFee = 0;
		foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/ } keys %{ $$feeMap{ $sym } } ) {
			my $prodFeeMap = $$feeMap{ $sym }{ $rtSubProd };
			$totBasicFee += $$prodFeeMap{ BASIC_FEE };
		}
		next if $totBasicFee <= 0;
		$totBasicFee = 20000 if $totBasicFee > 20000;
		
#		print "[$sym] RT fees too high by [$totBasicFee]...\n";

		foreach my $rtSubProd ( grep { $_ =~ /_RT/ } keys %{ $$feeMap{ $sym } } ) {
			my $prodFeeMap = $$feeMap{ $sym }{ $rtSubProd };
			my $totFeeMap = $$feeMap{ TOTAL }{ $rtSubProd };
			my $basicFee = $$prodFeeMap{ BASIC_FEE };
			if ( $basicFee > 0 ) {
				my $origNetFee = $$prodFeeMap{ NET_FEE };
				my $feeDiff = ( $basicFee < $totBasicFee ? $basicFee : $totBasicFee );
#				print "...[$sym] [$rtSubProd] reducing net fee from [$origNetFee] to [" , $basicFee - $feeDiff , "]...\n";
				$$prodFeeMap{ NET_FEE } = $basicFee - $feeDiff;
				$$totFeeMap{ NET_FEE } -= ( $origNetFee - ( $basicFee - $feeDiff ) );
				$totBasicFee -= $feeDiff;
				last if $totBasicFee == 0;
			}
		}
	}
}

sub max {
	my ( $a , $b ) = @_;
	return ( $a > $b ? $a : $b );
}

sub min {
	my ( $a , $b ) = @_;
	return ( $a < $b ? $a : $b );
}

sub abs {
	my ( $a ) = @_;
	return ( $a < 0 ? $a * -1 : $a );
}

sub cmpVal {
	my ( $a , $b ) = @_;
	return ( abs ( $a - $b ) >= 0.01 );
}

	
# ===================================================================================================	
	
my $RT_REBATE_CAP = 20000;

my $symFile = new SymbolSumm (
					file	=> $ARGV[ 0 ]
				);
my %valMap = ();

foreach my $keyMap ( grep { $_->{PRODUCT} =~ /[^F]_RT/ } @{ $symFile->allKeys () } ) {
	foreach my $feeType ( qw ( BASIC_FEE NET_FEE ) ) {
		my $fee = $symFile->val ( $keyMap , $feeType );
		$valMap{ $keyMap->{SYMBOL} }{ $keyMap->{PRODUCT} }{ $feeType } = $fee;
		$valMap{ $keyMap->{SYMBOL} }{ 'TOTAL' }{ $feeType } += $fee;
	}	 
}

foreach my $sym ( keys %valMap ) {
	my $basicFee = $valMap{ $sym }{ TOTAL }{ BASIC_FEE };
	
	if ( $basicFee > 0 ) {
		my $netFee = $valMap{ $sym }{ TOTAL }{ NET_FEE };
		my $theorNetFee = max ( 0 , $basicFee - $RT_REBATE_CAP );
		
#		printf "%s,%.2f,%.2f,%.2f,%s\n" , $sym , $basicFee , $theorNetFee , $netFee , ( cmpVal ( $netFee , $theorNetFee ) ? "N" : "Y" );
		
		if ( cmpVal ( $netFee , $theorNetFee ) ) {
	
			printf "%s,%.2f,%.2f,%.2f\n" , $sym , $basicFee , $theorNetFee , $netFee;
#			foreach my $prod ( keys %{ $valMap{ $sym } } ) {
#				foreach my $feeType ( keys %{ $valMap{ $sym }{ $prod } } ) {
#					printf "%s,%s,%s,%.2f\n" , $sym , $prod , $feeType , $valMap{ $sym }{ $prod }{ $feeType };
#				}
#			}
#			print "\n";
			
		}
	}
}

		
__DATA__
	

foreach my $sym ( $symFile->keys ( 'SYMBOL' ) ) {
	foreach my $rtSubProd ( grep { $_ =~ /[^F]_RT/

