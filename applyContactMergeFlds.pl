#!c:/perl/bin/perl

open MF , $ARGV[ 0 ];
<MF>;
while ( <MF> ) {
	chomp;
	( $acctID , $owner , $acctName , $contName , $fldName , $tmxVal , $alphaVal , $fldVal ) = split /,/;
	$fldValMap{ $acctId }{ $contName }{ $fldName } = $fldVal;
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
	my ( $acctId , $contName ) = @flds[ 3 , 8 ];
#	print "WAS : [$_]\n";
	foreach my $fldName ( keys %{ $fldValMap{ $acctId }{ $contName } } ) {
		$fldIdx = $hdrMap{ $fldName };
		$flds[ $fldIdx ] = $fldValMap{ $acctId }{ $contName}{ $fldName };
#		print "...Fld [$fldIdx] [$fldName] = [$fldValMap{ $id }{ $fldName }]\n";
	}
	my $rec = join ( "," , @flds );
	print "$rec\n";
	
}
close RECS;
