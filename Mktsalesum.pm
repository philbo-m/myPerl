package Mktsalesum;

use strict;

sub new {
	my ( $class , $file ) = @_;
	my $self = {
		file	=> $file
	};
	
	bless $self;
	
	$self->{feeMap} = $self->parse;
	
	return $self;
}

sub parse {
	my $self = shift;
	
	my %feeMap = ();
	
	open FILE , $self->{file};
	<FILE>;		# --- skip header ---
	while ( <FILE> ) {
		chomp;
		s/"//g;
		my ( $po , $mktId , $subProduct , $basicFee , $netFee ) = split /,/;
		$feeMap{ $po }{ $subProduct }{ "BASIC" } = $basicFee;
		$feeMap{ $po }{ $subProduct }{ "NET" } = $netFee;
	}
	close FILE;
	
	return \%feeMap;
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
