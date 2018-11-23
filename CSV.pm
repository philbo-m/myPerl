package CSV;

require Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw ( parseRecs fldsToRec fldsToRecs );

use strict;

sub parseRecs {
	my ( $recs ) = @_;
	my @outRecs = ();
	my $outFlds = [];
	my ( $carryFld , $inPartFld );
	my $recNo = 1;
	
	foreach my $line ( split ( /\r?\n/ , $recs ) ) {

#		print STDERR "LINE [$line]\n";
		foreach my $fld ( split /,/ , $line , -1 ) {
			
#			print "FLD [$fld]...\n";
			if ( !$inPartFld && $fld =~ /^"/ ) {	# --- Field starts with " : START OF QUOTED FLD ---
#				print "...in partial field...\n";
				$inPartFld = 1;
			}
		
			if ( $inPartFld ) {
				if ( $carryFld ) {
#					print "...prepending carry field [$carryFld] to field [$fld]...\n";
					$fld = $carryFld . $fld;				
				}
				if ( $fld eq '""' || ( $fld ne '"' && $fld =~ /("+)$/ && ( length ( $1 ) % 2 == 1 ) ) ) {	# Field is "", or field ends with " (or """, or ...) : END OF QUOTED FLD ---
#					print "...out of partial field [$fld]...\n";
					$inPartFld = 0;
					$carryFld = undef;
				}
			}
		
			if ( $inPartFld ) {
				$carryFld ="$fld,";
				next;
			}
		
			$fld =~ s/^"(.*)"$/$1/s;	# --- strip leading and trailing quotes ---
			$fld =~ s/""/"/gs;			# --- convert quoted quotes to single ---
#			print "FLD NOW {{{$fld}}}\n";
		
			push @$outFlds , $fld;
		}
		
		if ( $inPartFld ) {
			$carryFld =~ s/,$//;
			$carryFld .= "\n";
		}
		else {
			push @outRecs , $outFlds;
#			print "...Rec #" , ++$recNo , "\n";
			$outFlds = [];
		}
	}
	
	return \@outRecs;
}

sub parseRec {
	my ( $rec ) = @_;
	
	my $outRecs = parseRecs ( $rec );
	return $$outRecs[ 0 ];
#	return ( parseRecs ( ( $rec ) ) )[ 0 ];
}

sub flattenFld {
	my ( $fld ) = @_;
	$fld =~ s/,/<COMMA>/g ; $fld =~ s/"/<QUOT>/g ; $fld =~ s/\n/<NL>/g;
	return $fld;
}

sub flattenRec {
	my ( $rec ) = @_;
	my @outRec = map { flattenFld ( $_ ) } @$rec;
	return \@outRec;
}

sub flattenRecs {
	my ( $recs ) = @_;
	my @outRecs = map { flattenRec ( $_ ) } @$recs;
	return \@outRecs;
}

sub unflattenFld {
	my ( $fld , $quoteAllFlds ) = @_;
	my $outFld = $fld;
	$outFld =~ s/<COMMA>/,/g ; $outFld =~ s/<QUOT>/""/g ; $outFld =~ s/<NL>/\012/g;
	if ( ( $outFld ne $fld ) || $quoteAllFlds ) {
		$outFld = "\"$outFld\"";
	}
	return $outFld;
}
		
sub unflattenRec {
	my ( $rec , $quoteAllFlds ) = @_;
	my @outRec = map { unflattenFld ( $_ , $quoteAllFlds ) } @$rec;
	return \@outRec;
}

sub unflattenRecs {
	my ( $recs , $quoteAllFlds ) = @_;
	print STDERR "[" , scalar @$recs , "] [$quoteAllFlds]\n";
	my @outRecs = map { unflattenRec ( $_ , $quoteAllFlds ) } @$recs;
	return \@outRecs;
}

sub fldsToRec {
	my ( $recArray ) = @_;
	my $recs = fldsToRecs ( [ $recArray ] );
	return $$recs[ 0 ];
}

sub fldsToRecs {
	my ( $recArrays ) = @_;
	my @recs;
	foreach my $recArray ( @$recArrays ) {
		my @flds = map {
						if ( /[,"\n]/ ) {
							s/"/""/gs;
							s/(.*)/"$1"/s;
						}
						$_;
					} @$recArray;
		push @recs , join ( "," , @flds );
	}
	
	return \@recs;
}

1;