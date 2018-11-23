#!c:/perl/bin/perl

open MF , $ARGV[ 0 ];
<MF>;
while ( <MF> ) {
	chomp;
	( $alphaID , $id , $name , $fldName , $tmxVal , $alphaVal , $fldVal ) = split /,/;
	$fldValMap{ $id }{ $fldName } = $fldVal;
}
close MF;

open RECS , $ARGV[ 1 ];
my $hdr = <RECS>;
chomp $hdr;
my $idx = 0;
my %hdrMap = map { $_ => $idx++ } split ( /,/ , $hdr );
print "$hdr\n";

while ( <RECS> ) {
	chomp;
	my @flds = split /,/;
	my $id = $flds[ 3 ];
#	print "WAS : [$_]\n";
	foreach my $fldName ( keys %{ $fldValMap{ $id } } ) {
		$fldIdx = $hdrMap{ $fldName };
		$flds[ $fldIdx ] = $fldValMap{ $id }{ $fldName };
#			print "...Fld [$fldIdx] [$fldName] = [$fldValMap{ $id }{ $fldName }]\n";
	}
	my $rec = join ( "," , @flds );
	print "$rec\n";
	
}
close RECS;
