#!c:/perl/bin/perl

use strict;

sub getFldMap {
	my ( $hdr , $fldIdxByName ) = @_;
	chomp $hdr;
	my @fldNames = split ( /,/ , $hdr );
	for ( my $fldIdx = 0 ; $fldIdx < scalar @fldNames ; $fldIdx++ ) {
		my $fldName = $fldNames[ $fldIdx ];
		$$fldIdxByName{ $fldName } = $fldIdx;
	}
}

my $relatedCSV = $ARGV[ 0 ];
my $lookupCSV = $ARGV[ 1 ];
my $lookupFldIdName = "\"$ARGV[ 2 ]\"";
my $lookupFldName = "\"$ARGV[ 3 ]\"";

my %idxByFld = ();

open CSV , $lookupCSV or die "Could not open lookup CSV file [$lookupCSV] : $!";
my $hdr = <CSV>;
getFldMap ( $hdr , \%idxByFld );
my $idFldIdx = $idxByFld{ '"ID"' };
my $nameFldIdx = $idxByFld{ '"NAME"' };

my %lookupNameById = ();
 
while ( <CSV> ) {
	chomp;
	my ( $id , $name ) = ( split /,/ )[ $idFldIdx , $nameFldIdx ];
	$lookupNameById{ $id } = $name;
}
close CSV;

%idxByFld = ();

open CSV , $relatedCSV or die "Could not open related-list CSV file [$relatedCSV] : $!";
my $hdr = <CSV>;
getFldMap ( $hdr , \%idxByFld );
my $lookupFldIdx = $idxByFld{ $lookupFldIdName };

chomp $hdr;
my @hdrFlds = split /,/ , $hdr;
print join ( "," , ( @hdrFlds[ 0 .. $lookupFldIdx ] , $lookupFldName , @hdrFlds[ $lookupFldIdx + 1 .. $#hdrFlds ] ) ) , "\n";

while ( <CSV> ) {
	chomp;
	my @flds = split /,/;
	my $lookupId = $flds[ $lookupFldIdx ];
	my $lookupName = $lookupNameById{ $lookupId };
	print join ( "," , ( @flds[ 0 .. $lookupFldIdx ] , $lookupName , @flds[ $lookupFldIdx + 1 .. $#flds ] ) ) , "\n";
}
close CSV;