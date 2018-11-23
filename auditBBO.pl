#!c:/perl/bin/perl

use strict;

sub applyATSSymBBO {
	my ( $ts , $sym , $ats , $bboInd , $bestPrice , $atsPrice , $bboMap ) = @_;
	
	$bboMap = $bboMap{ $sym }{ $ats }{ $bboInd };
	$bboMap = {} if !$bboMap;
	
	if ( $bestPrice == $atsPrice ) {
		if ( !$$bboMap{ startAtBBO } ) {
			$bboMap{ startAtBBO } = $ts;
		}
	}
	else {
		
	
my ( $mktOpen , $mktClose ) = ( "09:30:00.000000" , "16:00:00.000000" );

my %atsNameByIdx = ();

my %nbboATSMap = (
	NBB		=> {} ,
	NBO		=> {}
);

my %

$_ = <>;
chomp ; s/"//g;
my @hdr = split /,/ );
for ( my $i = 11 ; $i < scalar @hdr ; $i += 3 ) {
	my $atsName = ( split ( /[_.]/ , $hdr[ $i ] ) )[ 1 ]; 
	$atsNameByIdx[ $i ] = $atsName;
}

while ( <> ) {
	chomp ; s/"//g;
	
	my @rec = split /,/;
	my ( $ts , $sym , $reason ) = @rec[ 0 , 1 , 9 ];
	next if $reason ne 'P';
	$ts = ( split ( /\s/ , $ts ) )[ 1 ];
	next if $ts lt $mktOpen;
	last if $ts gt $mktClose;
	
	my ( $nbb , $nbo ) = @rec[ 5 , 6 ];
	my ( $nbbChgd , $nboChgd ) = @rec[ 7 , 8 ];
	
	if ( $nbbChgd ) {
		
	for ( my $i = 11 ; $i < scalar @rec ; $i += 3 ) {
		my $ats = $atsNameByIdx{ $i };
		my ( $bb , $bo ) = @rec[ $i + 1 , $i + 2 ];
		
		if ( $bb == $nbb ) {
			push @
	}
	
	print "[$ts] [$0]\n";
}
	