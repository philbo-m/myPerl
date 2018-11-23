#!c:/perl/bin/perl

sub scrubFld {
	my ( $fld ) = @_;
	$fld =~ s/^"(.*)"$/$1/;
	$fld =~ s/^\*\*\*(.*)\*\*\*$/$1/;
	$fld =~ s/<(COMMA|NL|QUOT)>/ /g;
	$fld =~ s/\bAve\.?\b/Avenue/g;
	$fld =~ s/\bSt\.?\b/Street/g;
	$fld =~ s/\bONT?\b/Ontario/gi;
	$fld =~ s/\W//g;
	
	return $fld;
}

sub cmpFld {
	my ( $prevFld , $fld ) = @_;
	my $prevScrubFld = scrubFld ( $prevFld );
	my $scrubFld = scrubFld ( $fld );
	print STDERR "...COMPARING [[$prevScrubFld]] WITH [[$scrubFld]]...\n";
	
	return( uc ( $prevScrubFld ) cmp uc ( $scrubFld ) );
}
	
sub cmpRecs {
	my ( $prevRec , $rec , $pfx , $hdr ) = @_;
	print STDERR "COMPARING\n  [[" , join (" | " , @$prevRec ) , "]]\nWITH\n  [[" , join ( " | " , @$rec ) , "]]\n\n";
	foreach my $idx ( 5 .. $#$rec ) {
		my $prevFld = $$prevRec[ $idx ];
		( my $fld = $$rec[ $idx ] ) =~ s/\*\*\*//g;
		my $cmp = cmpFld ( $prevFld , $fld );
		if ( $cmp ) {
			print "$pfx,$$hdr[ $idx ],$prevFld,$fld\n";
		}
	}
}
	
	
my $hdr = <>;
chomp $hdr;
my @hdr = split /,/ , $hdr;
my ( @rec , @prevRec );

print join ( "," , @hdr[ 2 .. 4 ] ) , ",FIELD,TMX_VAL,ALPHA_VAL\n";

while ( <> ) {
	chomp;
	@rec = split /,/;
	if ( $rec[ 0 ] eq 'ALPHA' ) {
		my $pfx = join ( "," , @prevRec[ 2 .. 4 ] );
		cmpRecs ( \@prevRec , \@rec , $pfx , \@hdr );
	}
	@prevRec = @rec;
}
	