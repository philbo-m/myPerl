#!c:/perl/bin/perl

use strict;

use Getopt::Long;
use Data::Dumper;

use CSV;

my @alwaysIgnoreFlds = qw ( ID ISDELETED MASTERRECORDID PARENTID OWNERID CREATEDDATE CREATEDBYID LASTMODIFIEDDATE LASTMODIFIEDBYID SYSTEMMODSTAMP LASTACTIVITYDATE LASTVIEWEDDATE LASTREFERENCEDDATE JIGSAWCOMPANYID );

sub stripKeyFld {
	my ( $keyFld ) = @_;
	$keyFld =~ s/\bInc\.?\b/Incorporated/i;
	$keyFld =~ s/\bLtd\.?\b/Limited/i;
	$keyFld =~ s/[^\w]//g;
	return uc ( $keyFld );
}

sub cmpVals {
	my ( $vals ) = @_;
	for ( my $i = 1 ; $i < scalar @$vals ; $i++ ) {
		return 1 if $$vals[ $i ] ne $$vals[ 0 ];
	}
	return 0;
}

sub cmpFlds {
	my @flds = @_;
#	print "[[" , join ( "]] [[" , @flds ) , "]]\n";
	@flds = grep {
				s/\bInc\.?\b/Incorporated/i;
				s/\bLtd\.?\b/Limited/i;
				s/\bAve\.?\b/Avenue/i;
				s/[^\w]//g;
				$_;
			} @flds;
#	print "[[" , join ( "]] [[" , @flds ) , "]]\n";
			
	return uc ( $flds[ 0 ] ) cmp uc ( $flds[ 1 ] );
}

sub mkOutput {
	my @flds = @_;
#	print "[[" , join ( "]] [[" , @flds ) , "]]\n";
	@flds = grep {
				s/<COMMA>/,/g;
				s/<QUOT>/$1""/g;
				s/<NL>/\012/g;
				$_
			} @flds;

#	print "[[" , join ( "]] [[" , @flds ) , "]]\n";
	return @flds;
}

sub readCSV {
	my ( $file , $keyFldName , $fldNames , $recMap ) = @_;
	
	open FILE , $file or die "Cannot open CSV file [$file] : $!";
	$_ = <FILE>;
	chomp;
	push @$fldNames , split ( /,/ );
	my $fldIdx = 0;
	my %fldNameByIdx = map { $fldIdx++ => $_ } @$fldNames;
	my %fldIdxByName = map { $fldNameByIdx{ $_ } => $_ } %fldNameByIdx;
	
	while ( <FILE> ) {
		chomp;
		my @flds = mkOutput ( split /,/ );
		my $keyFld = $flds[ $fldIdxByName{ $keyFldName } ];
		my %fldMap = ();
		for ( my $fldIdx = 0 ; $fldIdx <= $#flds ; $fldIdx++ ) {
			my $fld = $flds[ $fldIdx ];
			$fldMap{ $fldNameByIdx{ $fldIdx } } = $fld;
		}
		my $stripFld = stripKeyFld ( $keyFld );
		if ( exists $$recMap{ $stripFld } ) {
			print STDERR "Key fld [$keyFld] [$stripFld] already encountered in [$file]\n";
		}
		else {
			$$recMap{ $stripFld } = \%fldMap;
		}
	}
	
	close FILE;
}

# NEITHER FLDS nor EXCL_FLDS specified - all flds except IGNORE_FLDS
# FLDS specified but not EXCL_FLDS - FLDS
# EXCL_FLDS specified but not FLDS - all flds except IGNORE_FLDS and EXCL_FLDS
# FLDS and EXCL_FLDS specified - FLDS except EXCL_FLDS
# ----------------------------------------------------------------------------
my ( $hasHeader , @flds , @exclFlds );
GetOptions ( 
	'h'		=> \$hasHeader ,
	'f=s'	=> \@flds ,
	'x=s'	=> \@exclFlds
) or die;

@flds = map { split /,/ } join ( "," , @flds );

@exclFlds = map { split /,/ } join ( "," , @exclFlds );
if ( !@flds ) {
	push @exclFlds , @alwaysIgnoreFlds;
}
my %exclFldMap = map { $_ => 1 } @exclFlds;

my %fldByIdx;
my $hdrRec;

if ( $hasHeader ) {
	my @hdrFlds;
	chomp ( $_ = <> );
	$_ = uc ( $_ );
	
	$hdrRec = CSV::parseRec ( $_ );
	for ( my $i = 0 ; $i < scalar @$hdrRec ; $i++ ) {
		$fldByIdx{ $i } = $$hdrRec[ $i ];
		if ( !@flds ) { 
			push @hdrFlds , $$hdrRec[ $i ];
		}
	}
	push @flds , @hdrFlds;
}

@flds = grep { !exists $exclFldMap{ $_ } } @flds;
my %fldMap = map { $_ => 1 } @flds;

my %fldMatrix;

my $save = $/;
$/ = undef;
my $recs = <>;
$/ = $save;

$recs = CSV::parseRecs ( $recs );

foreach my $rec ( @$recs ) {
	for ( my $i = 0 ; $i < scalar @$rec ; $i++ ) {
		my $fldName = ( $hasHeader ? $$hdrRec[ $i ] : $i );
		next if ( $hasHeader && !exists $fldMap{ $fldName } );
		push @{ $fldMatrix{ $fldName } } , $$rec[ $i ];
	}
}

print "FIELD," , join ( "," , map { "RECORD_" . $_ } ( 1 .. scalar @$recs ) ) , "\n";
		
foreach my $fldName ( keys %fldMatrix ) {
	if ( cmpVals ( $fldMatrix{ $fldName } ) ) {
		print "$fldName," , CSV::fldsToRec ( $fldMatrix{ $fldName } ) , "\n";
	}
}


__DATA__

my @dataRecs;
while ( <> ) {
	push @dataRecs , CSV::parseRec ( $_ );
}



my $alphaCSV = $ARGV[ 0 ];
my $tmxCSV = $ARGV[ 1 ];

my $keyFld = '"NAME"';
my ( @tmxFldNames , @alphaFldNames ) = ( () , () );
my ( %alphaRecMap , %tmxRecMap ) = ( () , () );

readCSV ( $alphaCSV , $keyFld , \@alphaFldNames , \%alphaRecMap );
readCSV ( $tmxCSV , $keyFld , \@tmxFldNames , \%tmxRecMap );

my $fldIdx = 0;
my %alphaFldMap = map { $_ => $fldIdx++ } @alphaFldNames;
$fldIdx = 0;
my %tmxFldMap = map { $_ => $fldIdx++ } @tmxFldNames;

my @sharedFldNames = ();

for ( my $fldIdx = $#alphaFldNames ; $fldIdx >= 0 ; $fldIdx-- ) {
	my $fldName = $alphaFldNames[ $fldIdx ];
	if ( exists $tmxFldMap{ $fldName } ) {
		unshift ( @sharedFldNames , $fldName );
		splice ( @alphaFldNames , $fldIdx , 1 );
		splice ( @tmxFldNames , $tmxFldMap{ $fldName } , 1 );
	}
} 

@sharedFldNames = grep { !$alwaysIgnoreFlds{ $_ } } @sharedFldNames;

my @masterNameList = keys %alphaRecMap;
push @masterNameList , keys %tmxRecMap;
my %masterNameList = map { $_ => 1 } @masterNameList;

binmode STDOUT;

my @hdr = qw ( Source Match ) ;
push @hdr , @sharedFldNames;
# push @hdr , @tmxFldNames;
# push @hdr , @alphaFldNames;
print join ( "," , @hdr ) , "\r\n";

foreach my $recName( sort keys %masterNameList ) {
	my $alphaRec = $alphaRecMap{ $recName };
	my $tmxRec = $tmxRecMap{ $recName };
	
	my @alphaOut = ( "ALPHA" );
	my @tmxOut = ( "TMX" );
	
	if ( $alphaRec && $tmxRec ) {
		push @alphaOut , "Y";
		push @tmxOut , "Y";
	}
	else {
		push @alphaOut , "";
		push @tmxOut , "";
	}
	
#	print "[$recName] [$alphaRec] [$tmxRec]\n";
#	print join ( " , " , keys %$tmxRec ) , "\n";
	foreach my $fldName ( @sharedFldNames ) {
		
#		print "...[$fldName] [$$alphaRec{ $fldName }] [$$tmxRec{ $fldName }]\n";
		if ( $alphaRec && $tmxRec ) {
			my $alphaVal = $$alphaRec{ $fldName };
			my $tmxVal = $$tmxRec{ $fldName };
			my $fldsMatch = !cmpFlds ( $alphaVal , $tmxVal );
			if ( $fldsMatch ) {
				$alphaVal =~ s/^"(.+)"$/"***$1***"/;
			}
			push @alphaOut , $alphaVal;
			push @tmxOut , $tmxVal;
		}
		elsif ( $alphaRec ) {
			push @alphaOut , $$alphaRec{ $fldName };
			push @tmxOut , "";
		}
		elsif ( $tmxRec ) {
			push @alphaOut , "";
			push @tmxOut , $$tmxRec{ $fldName };
		}
	}
	foreach my $fldName ( @alphaFldNames ) {
#		push @alphaOut , ( $alphaRec ? $$alphaRec{ $fldName } : "" );
#		push @tmxOut , "";
	}
	foreach my $fldName ( @tmxFldNames ) {
#		push @alphaOut , "";
#		push @tmxOut , ( $tmxRec ? $$tmxRec{ $fldName } : "" );
	}
	
	print join "," , @tmxOut , "\r\n";
	print join "," , @alphaOut , "\r\n";
	
}
