#!c:/perl/bin/perl

use strict;

my %qualifierMap = (
	IR	=> "ir" ,
	PF	=> "_pf" ,
	PR	=> "_p" ,
	RT	=> "_r" ,
	UN	=> "_u" ,
	WT	=> "_t"
);

sub symToRic {
	my ( $sym ) = @_;
	my $ric;
	
	if ( $sym =~ /^[A-Z]+$/ ) {
		$ric = $sym;
	}
	else {
		my @symParts = split /\./ , $sym;
		$ric = $symParts[ 0 ];
		if ( scalar @symParts > 1 ) {
			my $qual = $qualifierMap{ $symParts[ 1 ] };
			$qual = lc ( $symParts[ 1 ] ) if !$qual;
			$ric .= $qual;
		}
		if ( $symParts[ 2 ] ) {
			$ric .= lc ( $symParts[ 2 ] );
		}
	}
	return $ric;
}


while ( <> ) {
	chomp;
	my ( $ric , $sym ) = split /,/;
	$ric =~ s/\.[^.]+$//;
	
	my $calcRic = symToRic ( $sym );
	
	print "$sym,$ric,$calcRic" , ( $ric eq $calcRic ? "" : ",MISMATCH" ) , "\n";
}
	
	