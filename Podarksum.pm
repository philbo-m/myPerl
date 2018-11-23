package Podarksum;

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
		my ( $po , $mktId , $subProduct , $vol , $val , $numTrdLegs , $basicFee ) = split /,/;
		$feeMap{ $po }{ $subProduct } += $basicFee;
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
			$totalMap{ $po }{ "FEE" } += $self->{feeMap}{ $po }{ $subProduct };
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
			$totalMap{ $subProduct }{ "FEE" } += $self->{feeMap}{ $po }{ $subProduct };
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

sub getPOTotals {
	my $self = shift;
	
	my %totalMap = ();
	foreach my $po ( keys %{ $self->{feeMap} } ) {
		foreach my $subProduct ( keys %{ $self->{feeMap}{ $po } } ) {
			$totalMap{ $po } += $self->{feeMap}{ $po }{ $subProduct }{ "BASIC" };
		}
	}
	return \%totalMap;
}

sub getGrandTotal {
	my $self = shift;
	
	my $totalMap = $self->getPOTotals;
	my $total = 0;
	foreach my $po ( keys %{ $totalMap } ) {
		$total += $$totalMap{ $po };
	}
	return $total;
}

1;
