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
#	print STDERR "...COMPARING [[$prevScrubFld]] WITH [[$scrubFld]]...\n";
	
	return( uc ( $prevScrubFld ) cmp uc ( $scrubFld ) );
}
	
sub cmpRecs {
	my ( $recs , $pfx , $hdr , $commonFlds ) = @_;
	my $numFlds;
	print STDERR "COMPARING (" , scalar @$recs , ") RECS:";
	foreach my $rec ( @$recs ) {
		print STDERR "\n  [[" , join ( " | " , @$rec ) , "]]";
		$numFlds = $#$rec;
	}
	print STDERR "\n\n";
	
	foreach my $idx ( 0 .. $numFlds ) {
		my $fldName = $$hdr[ $idx ];
		next if !exists $$commonFlds{ $fldName };
		
		my $cmp = 0;
		foreach my $i ( 1 .. $#$recs ) {
			$cmp = cmpFld ( $$recs[ $0 ][ $idx ] , $$recs[ $i ][ $idx ] );
			if ( $cmp ) {
#				print STDERR "...FLDS [0] AND [$i] DIFFER\n";
				last;
			}
		}
		if ( $cmp ) {
			print "$pfx,$fldName," , join ( "," , map { $$_[ $idx ] } @$recs ) , "\n";
		}
	}
}

my @commonFlds = qw ( SALUTATION OTHERSTREET OTHERCITY OTHERSTATE OTHERPOSTALCODE OTHERCOUNTRY OTHERLATITUDE OTHERLONGITUDE MAILINGSTREET MAILINGCITY MAILINGSTATE MAILINGPOSTALCODE MAILINGCOUNTRY MAILINGLATITUDE MAILINGLONGITUDE PHONE FAX MOBILEPHONE HOMEPHONE OTHERPHONE ASSISTANTPHONE REPORTSTOID EMAIL TITLE DEPARTMENT ASSISTANTNAME BIRTHDATE DESCRIPTION HASOPTEDOUTOFEMAIL EMAILBOUNCEDREASON EMAILBOUNCEDDATE JIGSAWCONTACTID CONTACT_TYPE__C );
my %commonFlds = map { $_ => 1 } @commonFlds;

my @ignoreFlds = qw ( OWNERID MASTERRECORDID CREATEDDATE CREATEDBYID LASTMODIFIEDDATE LASTMODIFIEDBYID SYSTEMMODSTAMP LASTACTIVITYDATE RECORDTYPEID ACCOUNTID );

my %ignoreFlds = map { $_ => 1 } @ignoreFlds;

my $hdr = <>;
chomp $hdr;
my @hdr = split /,/ , $hdr;

print join ( "," , @hdr[ 3 , 4 , 8 ] ) , ",FIELD,\n";

my @commonRecs = ();
my ( $pfx , $dispPfx , $prevPfx , $prevDispPfx );

while ( <> ) {
	chomp;
	my @rec = split /,/;
	my ( $action , $acctId , $acctName , $name ) = @rec[ 1 , 3 , 4 , 8 ];
	print STDERR "[$action] [$acctId] [$acctName] [$name]\n";
	if ( $action eq 'M' ) {
		my $nextRec = <>;
		chomp $nextRec;
		my @nextRec = split /,/ , $nextRec;
		if ( $nextRec[ 1 ] ne 'M' ) {
			print STDERR "ERROR ERROR : NOT TWO CONSECUTIVE MERGE RECS at rec [$.]\n";
			exit;
		}
		my $pfx = "$acctId,$acctName,$name";
		cmpRecs ( [ \@rec , \@nextRec ] , $pfx , \@hdr , \%commonFlds );
	}
}


__DATA__
	next if $action ne 'M';
	$pfx = "$acctId,$name";
	$dispPfx = "$acctId,$acctName,$name";
	if ( $pfx ne $prevPfx && $prevPfx != "" ) {
		print STDERR "[$prevPfx] [$pfx]\n";
		if ( @commonRecs ) {
			cmpRecs ( \@commonRecs , $prevDispPfx , \@hdr , \%commonFlds );
		}
		@commonRecs = ();
		$prevPfx = undef;
	}
	$prevPfx = $pfx;
	$prevDispPfx = $dispPfx;
	push @commonRecs , \@rec;
}

print STDERR "LAST RECS\n";
cmpRecs ( \@commonRecs , $prevDispPfx , \@hdr , \%commonFlds );
	