#!c:/perl/bin/perl

use strict;

sub parseBlock {
	my ( $recs ) = @_;
	
	while ( <> ) {
		chomp;
		my @flds = split /,/;
		if ( $flds[ 0 ] ) {
			return \@flds;
		}
		push @$recs , \@flds;
	}
}


sub processBlock {
	my ( $recList , $checkListByType , $attrListByTypeCheck , $checkByPOFirmAcct ) = @_;
	
	my ( $blockType , $firstBlock );
	if ( $$recList[ 0 ][ 2 ] eq '' ) {

#		--- PO/Firm type block ---
		$blockType = 'PO';
	}
	else {
	
#		--- Account type block ---
		$blockType = 'ACCT';
	}
	$firstBlock = ( !defined $$checkListByType{ $blockType } );

	my ( $prevRec , $prevCheck );
	foreach my $rec ( @$recList ) {
	
#		Flesh out the records in the list, for convenience.
#		---------------------------------------------------
		for ( my $i = 0 ; $i <= $#$rec ; $i++ ) {
			$$rec[ $i ] = $$prevRec[ $i ] if ( $prevRec && $$rec[ $i ] eq '' );
		}
		$prevRec = $rec;
		
		my ( $po , $firm , $acct , $check , $attr , $val ) = @$rec;

		if ( $firstBlock ) {
			if ( $check && $check ne $prevCheck ) {
				push @{ $$checkListByType{ $blockType } } , $check;
				$prevCheck = $check;
			}
			push @{ $$attrListByTypeCheck{ $blockType }{ $check } } , $attr;
		}
		
#		print "[" , join ( " , " , @$rec ) , "]\n";
		
		$$checkByPOFirmAcct{ $po }{ $firm }{ $acct }{ $check }{ $attr } = $val;

	}	
}

sub mkHdrRecs {
	my ( $hdrRecs , $checkList , $attrListByCheck ) = @_;
	
	foreach my $check ( @$checkList ) {
		push @{ $$hdrRecs[ 0 ] } , $check;
#		print "[$check] [" , $#{ $$attrListByCheck{ $check } } , "]...\n";
		for ( my $i = 0 ; $i <= $#{ $$attrListByCheck{ $check } } ; $i++ ) {
#			print "...[$i] [" , ${ $$attrListByCheck{ $check } }[ $i ] , "]...\n";
			push @{ $$hdrRecs[ 1 ] } , ${ $$attrListByCheck{ $check } }[ $i ];
			if ( $i > 0 ) {
				push @{ $$hdrRecs[ 0 ] } , "";
			}
		}
	}
}

		
my $inPOBlock = 0;
my $inAcctBlock = 0;
my ( $po , $firm , $acct );
my @POCheckList = ();
my @acctCheckList = ();
my %attrsByAcctCheck = ();

my %checkByPOFirm = ();
my %checkByPOFirmAcct = ();

my ( $prevAcct , $prevCheck );
my ( $firstPO , $firstAcct ) = ( 1 , 1 );

binmode STDIN;

my @flds;
my @recList = ();

my %checkListByType = ();
my %attrListByTypeCheck = ();
my %checkByPOFirmAcct = ();

while ( <> ) {

	chomp;
	@flds = split /,/;
	last if ( scalar ( @flds ) == 6 && $flds[ 0 ] ne 'PO' );
}
push @recList , \@flds;

while ( my $nextRec = parseBlock ( \@recList ) ) {
	processBlock ( \@recList , \%checkListByType , \%attrListByTypeCheck , \%checkByPOFirmAcct );
	@recList = ( $nextRec );
}

processBlock ( \@recList , \%checkListByType , \%attrListByTypeCheck , \%checkByPOFirmAcct );

my @hdrRecs = ( [ "PO" , "Firm" ] , [ "" , "" ] );
mkHdrRecs ( \@hdrRecs , $checkListByType{ "PO" } , $attrListByTypeCheck{ "PO" } );
print join ( "," , @{ $hdrRecs[ 0 ] } ) , "\n";
print join ( "," , @{ $hdrRecs[ 1 ] } ) , "\n";

foreach my $po ( sort keys %checkByPOFirmAcct ) {
	foreach my $firm ( sort keys %{ $checkByPOFirmAcct{ $po } } ) {
		print "$po,$firm";
		foreach my $check ( @{ $checkListByType{ "PO" } } ) {
			foreach my $attr ( @{ $attrListByTypeCheck{ "PO" }{ $check } } ) {
				print "," , $checkByPOFirmAcct{ $po }{ $firm }{ "" }{ $check }{ $attr };
			}
		}
		print "\n";
	}
}

print "\n\n";

@hdrRecs = ( [ "PO" , "Firm" , "Acct" ] , [ "" , "" , "" ] );
mkHdrRecs ( \@hdrRecs , $checkListByType{ "ACCT" } , $attrListByTypeCheck{ "ACCT" } );
print join ( "," , @{ $hdrRecs[ 0 ] } ) , "\n";
print join ( "," , @{ $hdrRecs[ 1 ] } ) , "\n";

foreach my $po ( sort keys %checkByPOFirmAcct ) {
	foreach my $firm ( sort keys %{ $checkByPOFirmAcct{ $po } } ) {
		foreach my $acct ( sort keys %{ $checkByPOFirmAcct{ $po }{ $firm } } ) {
			next if !$acct;
			print "$po,$firm,$acct";
			foreach my $check ( @{ $checkListByType{ "ACCT" } } ) {
				foreach my $attr ( @{ $attrListByTypeCheck{ "ACCT" }{ $check } } ) {
					print "," , $checkByPOFirmAcct{ $po }{ $firm }{ $acct }{ $check }{ $attr };
				}
			}
			print "\n";
		}
	}
}

__DATA__
foreach my $po ( sort keys %checkByPOFirmAcct ) {
	foreach my $firm ( sort keys %{ $checkByPOFirmAcct{ $po } } ) {
		foreach my $acct ( sort keys %{ $checkByPOFirmAcct{ $po }{ $firm } } ) {
			print "$po,$firm,$acct";
			foreach my $check ( @acctCheckList ) {
				foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
					print "," , $checkByPOFirmAcct{ $po }{ $firm }{ $acct }{ $check }{ $attr };
				}
			}
			print "\n";
		}
	}
}

__DATA__
print "\n";
print ",,";
foreach my $check ( @acctCheckList ) {
	foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
		print ",$attr";
	}
}
foreach my $po ( sort keys %checkByPOFirm ) {
	foreach my $firm ( sort keys %{ $checkByPOFirm{ $po } } ) {
		print "$po,$firm";
		foreach my $check ( @POCheckList ) {
			print ",$checkByPOFirm{ $po }{ $firm }{ $check }";
		}
		print "\n";
	}
}
print "\n\n";

print "PO,Firm,Account,";
foreach my $check ( @acctCheckList ) {
	print "$check,";
	foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
		print ",";
	}
}
print "\n";
print ",,";
foreach my $check ( @acctCheckList ) {
	foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
		print ",$attr";
	}
}
print "\n";
exit;	

__DATA__
		foreach my $fld ( @$rec ) {
			if ( $fld eq '' ) {
				$$rec
		my ( $po , $firm , $acct , $check , $attr , $val ) = split /,/ , @$rec;
		
	
	if ( $po && !$acct ) {
	
#		--- New PO or PO/Firm section ---
		$inPOBlock = 1;
		$inAcctBlock = 0;
		$firstPO = ( !$prevPO );
			
		$prevPO = $po;
	}
	
	elsif ( $po && $acct ) {

#		--- New PO/Firm/Acct section ---
		$inPOBlock = 0;
		$inAcctBlock = 1;
		$firstAcct = ( !$prevAcct );

		$prevAcct = $acct;
	}
	
	( $prevPO , $prevFirm , $prevAcct , $prevCheck ) = ( $po , $firm , $acct , $check );
		
	if ( $inPOBlock ) {
		if ( $firstPO ) {
			push @POCheckList , $check;
		}
	}
	
	elsif ( $inAcctBlock ) {
		if ( $firstAcct ) {
			if ( $check && $check ne $prevCheck ) {
				push @acctCheckList , $check;
			}
			if ( $attr ) {
				push @{ $attrsByAcctCheck{ $check } } , $attr;
			}

	
	if ( $po && $po ne $prevPO ) 
	if ( $flds[ 0 ] ne '' && $flds[ 2 ] eq '' ) {
		$inPOBlock = 1;
		if ( $inAcctBlock ) {
			$inAcctBlock = 0;
		}
		( $po , $firm ) = @flds[ 0 , 1 ];
	}
	elsif ( $flds[ 2 ] ne '' ) {
		if ( $inPOBlock ) {
			$firstPO = 0;
			$inPOBlock = 0;
			$inAcctBlock = 1;
		}
		if ( $inAcctBlock ) {
			$acct = $flds[ 2 ];
			if ( $acct ne $prevAcct ) {
				if ( $prevAcct ) {
					$firstAcct = 0;
				}
				$prevAcct = $acct;
			}
		}
	}
	
	my ( $check , $attr , $val ) = @flds[ 3 , 4 , 5 ];
	
	if ( $inPOBlock ) {
#		print "[$inPOBlock] [$inAcctBlock] [$firstPO] $po , $firm , $check , $attr , $val\n";
		if ( $firstPO ) {
			push @POCheckList , $check;
		}
		my $checkVal = $val;
		$checkVal .= " ($attr)" if $attr;
		$checkByPOFirm{ $po }{ $firm }{ $check } = $checkVal;
	}
	
	elsif ( $inAcctBlock ) {
#		print "[$inPOBlock] [$inAcctBlock] [$firstAcct] $po , $firm , $acct , $check , $attr , $val\n";
		if ( $firstAcct ) {
			if ( $check && $check ne $prevCheck ) {
				push @acctCheckList , $check;
			}
			if ( $attr ) {
				push @{ $attrsByAcctCheck{ $check } } , $attr;
			}
		}
		if ( $check ne $prevCheck ) {
			if ( $check ) {
				$prevCheck = $check;
			}
			elsif ( $prevCheck ) {
				$check = $prevCheck;
			}
		}
			
#		print "[$_]\n";
#		print "[$po] [$firm] [$acct] [$check] [$attr] [$val]...\n";
		$checkByPOFirmAcct{ $po }{ $firm }{ $acct }{ $check }{ $attr } = $val;
	}
}

print "PO,Firm," , join ( "," , @POCheckList ) , "\n";
foreach my $po ( sort keys %checkByPOFirm ) {
	foreach my $firm ( sort keys %{ $checkByPOFirm{ $po } } ) {
		print "$po,$firm";
		foreach my $check ( @POCheckList ) {
			print ",$checkByPOFirm{ $po }{ $firm }{ $check }";
		}
		print "\n";
	}
}
print "\n\n";

print "PO,Firm,Account,";
foreach my $check ( @acctCheckList ) {
	print "$check,";
	foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
		print ",";
	}
}
print "\n";
print ",,";
foreach my $check ( @acctCheckList ) {
	foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
		print ",$attr";
	}
}
print "\n";
foreach my $po ( sort keys %checkByPOFirmAcct ) {
	foreach my $firm ( sort keys %{ $checkByPOFirmAcct{ $po } } ) {
		foreach my $acct ( sort keys %{ $checkByPOFirmAcct{ $po }{ $firm } } ) {
			print "$po,$firm,$acct";
			foreach my $check ( @acctCheckList ) {
				foreach my $attr ( @{ $attrsByAcctCheck{ $check } } ) {
					print "," , $checkByPOFirmAcct{ $po }{ $firm }{ $acct }{ $check }{ $attr };
				}
			}
			print "\n";
		}
	}
}
				
		

		