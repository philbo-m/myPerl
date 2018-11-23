package Tdrsalesum;

use strict;

sub new {
	my ( $class , $file ) = @_;
	my $self = {
		file	=> $file
	};
	
	bless $self;
	
	( $self->{feeMap} , $self->{volMap} , $self->{valMap} ) = $self->parse;
	
	return $self;
}

sub parse {
	my $self = shift;
	
	my %feeMap = ();
	my %volMap = ();
	my %valMap = ();
	
	open FILE , $self->{file};
	<FILE>;		# --- skip header ---
	while ( <FILE> ) {
		chomp;
		s/"//g;
		my ( $po , $trdrId , $mkt , $sym , $subProduct , $vol , $val , $numTrdLegs , $actVol , $pasVol , $basicFee , $netFee )
				= split /,/;
				
		$feeMap{ $po }{ $subProduct }{ "BASIC" } += $basicFee;
		$feeMap{ $po }{ $subProduct }{ "NET" } += $netFee;
		$volMap{ $po }{ $subProduct } += $vol;
		$valMap{ $po }{ $subProduct } += $val;
	}
	close FILE;
	
	return ( \%feeMap , \%volMap , \%valMap );
}

sub getPOTotals {
	my $self = shift;
	
	my %totalMap = ();
	
	foreach my $po ( keys %{ $self->{feeMap} } ) {
		foreach my $subProduct ( keys %{ $self->{feeMap}{ $po } } ) {
			$totalMap{ $po }{ "FEE" } += $self->{feeMap}{ $po }{ $subProduct }{ "BASIC" };
			$totalMap{ $po }{ "VOL" } += $self->{volMap}{ $po }{ $subProduct };
			$totalMap{ $po }{ "VAL" } += $self->{valMap}{ $po }{ $subProduct };
		}
	}
	return \%totalMap;
}

sub getSubProductTotals {
	my $self = shift;
	
	my %totalMap = ();
	
	foreach my $po ( keys %{ $self->{feeMap} } ) {
		foreach my $subProduct ( keys %{ $self->{feeMap}{ $po } } ) {
			$totalMap{ $subProduct }{ "FEE" } += $self->{feeMap}{ $po }{ $subProduct }{ "BASIC" };
			$totalMap{ $subProduct }{ "VOL" } += $self->{volMap}{ $po }{ $subProduct };
			$totalMap{ $subProduct }{ "VAL" } += $self->{valMap}{ $po }{ $subProduct };
		}
	}
	return \%totalMap;
}

sub getGrandTotals {
	my $self = shift;
	
	my %totalMap = ();
	my $poTotalMap = $self->getPOTotals;
	foreach my $po ( keys %{ $poTotalMap } ) {
		$totalMap{ "FEE" } += $$poTotalMap{ $po }{ "FEE" };
		$totalMap{ "VOL" } += $$poTotalMap{ $po }{ "VOL" };
		$totalMap{ "VAL" } += $$poTotalMap{ $po }{ "VAL" };
	}
	return \%totalMap;
}

1;
